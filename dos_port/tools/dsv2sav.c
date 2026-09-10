/* dsv2sav.c -- Portable Pokemon Yellow DOS port .dsv <-> .sav converter.
 *
 * Converts between the DOS port's POKEMON.DSV save format (v2: a 7-byte
 * header prepended to the raw 32,768-byte MBC5 SRAM image) and standard
 * Game Boy .sav files (the raw 32,768-byte SRAM image alone). Conversion
 * is lossless and exactly invertible in both directions.
 *
 * Usage:
 *   dsv2sav --to-sav IN.dsv OUT.sav   DOS save -> GB SRAM dump (validate,
 *                                     strip the 7-byte header)
 *   dsv2sav --to-dsv IN.sav OUT.dsv   GB SRAM dump -> DOS save (prepend the
 *                                     7-byte header with fresh checksum)
 *   dsv2sav --verify FILE.dsv         validate a .dsv file (DeSmuME probe,
 *                                     size, magic, version, checksum) and
 *                                     print a summary
 *   dsv2sav --info FILE.dsv           alias of --verify
 *   dsv2sav --help                    print usage
 *
 * (--to-dos is accepted as an alias of --to-dsv, and --to-gb as an alias
 * of --to-sav, matching dos_port/tools/saveconv.py's option names.)
 *
 * .dsv format -- version 2 (written by dos_port/src/save/dsv_io.asm):
 *     Offset  Size   Description
 *     0x00    4      Magic: "DOSV"
 *     0x04    1      Format version (currently 2)
 *     0x05    2      16-bit ADDITIVE checksum of the payload, little-endian
 *     0x07    32768  Payload: the raw emulated SRAM image, bank 0 first --
 *                    the same bank order as a real MBC5 .sav.
 *     Total file = 32775 bytes.
 *
 * Checksum: sum of every payload byte, modulo 2^16, stored LE. NOT a CRC --
 * matched to what dsv_io.asm:dsv_checksum actually computes (accumulates
 * with `add ax, dx`, wrapping at 16 bits).
 *
 * --verify checks exactly what src/save/dsv_io.asm:SramLoadImage checks
 * before it scatters a file back into the SRAM banks (full length, magic,
 * version, checksum), plus a DeSmuME footer probe first: DeSmuME (the
 * Nintendo DS emulator) also uses the .dsv extension but appends a 122-byte
 * footer whose last 16 bytes are "|-DESMUME SAVE-|". dsv_io.asm itself has
 * no such probe (a foreign file simply fails its size check and reads as
 * "no save"); the probe here exists to tell the user WHY, and how to get
 * a usable file out of DeSmuME (File -> Export Backup Memory).
 *
 * Portability (must compile and run identically on little- and big-endian
 * CPUs with any ISO C compiler):
 *   - Only standard headers: <stdio.h>, <stdlib.h>, <string.h>, <stdint.h>.
 *   - Multi-byte integers are serialized explicitly, byte by byte, with
 *     shifts and masks -- never by casting a byte pointer to a multi-byte
 *     integer pointer.
 *     Pointer casts would read the wrong value on big-endian CPUs and can
 *     fault on strict-alignment architectures (SPARC, older ARM/MIPS).
 *   - Magic comparison uses memcmp, never an integer comparison.
 *   - The checksum accumulates byte-by-byte into a uint16_t, which wraps at
 *     16 bits on every architecture.
 *
 * Compiles cleanly with any ISO C99 / C89 compiler:
 *   gcc -O2 -std=c99 -Wall -Wextra -pedantic -o dsv2sav dsv2sav.c
 *   clang -O2 -std=c99 -Wall -Wextra -pedantic -o dsv2sav dsv2sav.c
 *   cl /O2 /W4 dsv2sav.c                                (MSVC)
 *   gcc -O2 -o dsv2sav.exe dsv2sav.c                    (MinGW / DJGPP)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define DSV_MAGIC_STR "DOSV"
#define DSV_VERSION   2
#define HDR_SIZE      7u
#define SAV_SIZE      32768u
#define DSV_SIZE      (HDR_SIZE + SAV_SIZE)   /* 32775 */

static const char DESMUME_COOKIE[] = "|-DESMUME SAVE-|";
static const char *prog = "dsv2sav";

/* --- Endian-neutral integer encoding (explicit shift/mask, byte by byte) --- */

static uint16_t read_u16_le(const uint8_t *p)
{
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static void write_u16_le(uint8_t *p, uint16_t v)
{
    p[0] = (uint8_t)(v & 0xFFu);
    p[1] = (uint8_t)((v >> 8) & 0xFFu);
}

static void write_u32_le(uint8_t *p, uint32_t v)
{
    p[0] = (uint8_t)(v & 0xFFu);
    p[1] = (uint8_t)((v >> 8) & 0xFFu);
    p[2] = (uint8_t)((v >> 16) & 0xFFu);
    p[3] = (uint8_t)((v >> 24) & 0xFFu);
}

/* 16-bit additive sum mod 2^16, byte by byte (mirrors dsv_checksum). */
static uint16_t payload_checksum(const uint8_t *payload, size_t len)
{
    uint16_t sum = 0;
    size_t i;
    for (i = 0; i < len; i++) {
        sum = (uint16_t)(sum + payload[i]);
    }
    return sum;
}

static int is_desmume(const uint8_t *data, size_t len)
{
    if (len < 16)
        return 0;
    return (memcmp(data + len - 16, DESMUME_COOKIE, 16) == 0);
}

/* --- File I/O (whole-file in memory; output via temp file + rename) --- */

static int read_file(const char *path, uint8_t **out_data, size_t *out_len)
{
    FILE *f;
    long size;
    uint8_t *buf;
    size_t got;

    f = fopen(path, "rb");
    if (f == NULL) {
        fprintf(stderr, "%s: error: cannot open '%s' for reading.\n", prog, path);
        return 0;
    }
    if (fseek(f, 0, SEEK_END) != 0) {
        fprintf(stderr, "%s: error: cannot seek '%s'.\n", prog, path);
        fclose(f);
        return 0;
    }
    size = ftell(f);
    if (size < 0) {
        fprintf(stderr, "%s: error: cannot tell size of '%s'.\n", prog, path);
        fclose(f);
        return 0;
    }
    if (fseek(f, 0, SEEK_SET) != 0) {
        fprintf(stderr, "%s: error: cannot rewind '%s'.\n", prog, path);
        fclose(f);
        return 0;
    }
    buf = (uint8_t *)malloc((size_t)size > 0 ? (size_t)size : 1);
    if (buf == NULL) {
        fprintf(stderr, "%s: error: out of memory reading '%s'.\n", prog, path);
        fclose(f);
        return 0;
    }
    got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) {
        fprintf(stderr, "%s: error: short read on '%s' (%u of %ld bytes).\n",
                prog, path, (unsigned)got, size);
        free(buf);
        return 0;
    }
    *out_data = buf;
    *out_len = (size_t)size;
    return 1;
}

/* Write `len` bytes to `path` atomically: the full image is composed in
 * memory by the caller, staged to "<path>.tmp" (fwrite + fflush + fclose),
 * then moved into place with rename(), which is atomic on the same
 * filesystem. A crash mid-write leaves either the old file or the temp
 * file behind -- never a torn POKEMON.DSV. All ISO C (stdio.h/stdlib.h). */
static int write_file_atomic(const char *path, const uint8_t *data, size_t len)
{
    char *tmp;
    size_t path_len;
    FILE *f;
    size_t wrote;

    path_len = strlen(path);
    tmp = (char *)malloc(path_len + 5);   /* ".tmp" + NUL */
    if (tmp == NULL) {
        fprintf(stderr, "%s: error: out of memory writing '%s'.\n", prog, path);
        return 0;
    }
    memcpy(tmp, path, path_len);
    memcpy(tmp + path_len, ".tmp", 5);

    f = fopen(tmp, "wb");
    if (f == NULL) {
        fprintf(stderr, "%s: error: cannot open '%s' for writing.\n", prog, tmp);
        free(tmp);
        return 0;
    }
    wrote = fwrite(data, 1, len, f);
    if (fflush(f) != 0)
        wrote = 0;   /* force the short-write path below */
    if (fclose(f) != 0)
        wrote = 0;
    if (wrote != len) {
        fprintf(stderr, "%s: error: short write on '%s' (%u of %u bytes).\n",
                prog, tmp, (unsigned)wrote, (unsigned)len);
        remove(tmp);
        free(tmp);
        return 0;
    }
    if (rename(tmp, path) != 0) {
        fprintf(stderr, "%s: error: cannot rename '%s' to '%s'.\n",
                prog, tmp, path);
        remove(tmp);
        free(tmp);
        return 0;
    }
    free(tmp);
    return 1;
}

/* --- Validation (mirrors dsv_io.asm:SramLoadImage check order,
 * --- with the DeSmuME probe first) --- */

static int validate_dsv(const char *path, const uint8_t *data, size_t len)
{
    uint16_t stored, computed;

    /* 1. DeSmuME footer probe (before size: a DS save is never ours,
     *    whatever its length). */
    if (is_desmume(data, len)) {
        fprintf(stderr,
                "%s: error: '%s' is a Nintendo DS (DeSmuME) save file.\n"
                "  DeSmuME and this DOS port both use the .dsv extension, but the formats differ.\n"
                "  To use a DeSmuME save, export a raw .sav in DeSmuME via File -> Export Backup Memory.\n",
                prog, path);
        return 0;
    }

    /* 2. Total size. A bare 32 KiB input is a raw GB .sav (the v2 payload
     *    without the header) -- by far the likeliest way to reach this
     *    branch, and worth naming. */
    if (len != DSV_SIZE) {
        if (len == SAV_SIZE) {
            fprintf(stderr,
                    "%s: error: '%s' is a raw Game Boy .sav (%u bytes), not a .dsv.\n"
                    "  Did you mean: %s --to-dsv \"%s\" output.dsv ?\n",
                    prog, path, (unsigned)SAV_SIZE, prog, path);
        } else {
            fprintf(stderr, "%s: error: '%s' has invalid size %u bytes (expected %u bytes).\n",
                    prog, path, (unsigned)len, (unsigned)DSV_SIZE);
        }
        return 0;
    }

    /* 3. Magic (memcmp -- never an integer comparison; see portability
     *    note at the top of this file). */
    if (memcmp(data, DSV_MAGIC_STR, 4) != 0) {
        fprintf(stderr, "%s: error: '%s' has invalid header magic (expected 'DOSV').\n",
                prog, path);
        return 0;
    }

    /* 4. Version byte (a v1 file fails here, by design -- no migration). */
    if (data[4] != DSV_VERSION) {
        fprintf(stderr, "%s: error: '%s' has unsupported version %u (supported: version %u).\n",
                prog, path, (unsigned)data[4], (unsigned)DSV_VERSION);
        return 0;
    }

    /* 5. Additive checksum over the opaque payload. */
    stored = read_u16_le(data + 5);
    computed = payload_checksum(data + HDR_SIZE, SAV_SIZE);
    if (stored != computed) {
        fprintf(stderr, "%s: error: '%s' payload checksum mismatch (stored 0x%04X, computed 0x%04X).\n",
                prog, path, (unsigned)stored, (unsigned)computed);
        return 0;
    }

    return 1;
}

/* Wrap a raw 32768-byte SRAM image in the 7-byte v2 header. The inverse of
 * stripping it: dsv_io.asm writes exactly this layout, so a file built here
 * is one SramLoadImage accepts. */
static void build_dsv(const uint8_t *payload, uint8_t *dsv)
{
    uint16_t checksum;
    memcpy(dsv, DSV_MAGIC_STR, 4);
    dsv[4] = DSV_VERSION;
    checksum = payload_checksum(payload, SAV_SIZE);
    write_u16_le(dsv + 5, checksum);
    memcpy(dsv + HDR_SIZE, payload, SAV_SIZE);
}

/* --- Modes --- */

static int mode_to_sav(const char *in_path, const char *out_path)
{
    uint8_t *data = NULL;
    size_t len = 0;
    uint16_t stored;
    int ok;

    if (!read_file(in_path, &data, &len))
        return 1;
    /* DeSmuME probe applies to the input whatever the mode: a DS save
     * passed as --to-sav input is never convertible. */
    if (is_desmume(data, len)) {
        fprintf(stderr,
                "%s: error: '%s' is a Nintendo DS (DeSmuME) save file.\n"
                "  DeSmuME and this DOS port both use the .dsv extension, but the formats differ.\n"
                "  To use a DeSmuME save, export a raw .sav in DeSmuME via File -> Export Backup Memory.\n",
                prog, in_path);
        free(data);
        return 1;
    }
    if (!validate_dsv(in_path, data, len)) {
        free(data);
        return 1;
    }
    stored = read_u16_le(data + 5);
    ok = write_file_atomic(out_path, data + HDR_SIZE, SAV_SIZE);
    if (ok) {
        printf("OK: %s -> %s\n", in_path, out_path);
        printf("  read                  %u bytes (valid version-%u .dsv, checksum 0x%04X)\n",
               (unsigned)len, (unsigned)DSV_VERSION, (unsigned)stored);
        printf("  wrote                 %u bytes (raw GB SRAM image)\n", (unsigned)SAV_SIZE);
    }
    free(data);
    return ok ? 0 : 1;
}

static int mode_to_dsv(const char *in_path, const char *out_path)
{
    uint8_t *payload = NULL;
    size_t len = 0;
    uint8_t *dsv;
    uint16_t stored;
    int ok;

    if (!read_file(in_path, &payload, &len))
        return 1;
    if (is_desmume(payload, len)) {
        fprintf(stderr,
                "%s: error: '%s' is a Nintendo DS (DeSmuME) save file.\n"
                "  DeSmuME and this DOS port both use the .dsv extension, but the formats differ.\n"
                "  To use a DeSmuME save, export a raw .sav in DeSmuME via File -> Export Backup Memory.\n",
                prog, in_path);
        free(payload);
        return 1;
    }
    if (len != SAV_SIZE) {
        if (len == DSV_SIZE) {
            fprintf(stderr,
                    "%s: error: '%s' is already a .dsv (%u bytes), not a raw .sav.\n"
                    "  Did you mean: %s --to-sav \"%s\" output.sav ?\n",
                    prog, in_path, (unsigned)DSV_SIZE, prog, in_path);
        } else {
            fprintf(stderr, "%s: error: '%s' has invalid size %u bytes (a raw GB .sav is %u bytes).\n",
                    prog, in_path, (unsigned)len, (unsigned)SAV_SIZE);
        }
        free(payload);
        return 1;
    }
    dsv = (uint8_t *)malloc(DSV_SIZE);
    if (dsv == NULL) {
        fprintf(stderr, "%s: error: out of memory.\n", prog);
        free(payload);
        return 1;
    }
    build_dsv(payload, dsv);
    /* Cheap self-check: the file we are about to write must pass the very
     * checks the port applies before it loads one. */
    if (!validate_dsv(out_path, dsv, DSV_SIZE)) {
        free(payload);
        free(dsv);
        return 1;
    }
    ok = write_file_atomic(out_path, dsv, DSV_SIZE);
    if (ok) {
        stored = read_u16_le(dsv + 5);
        printf("OK: %s -> %s\n", in_path, out_path);
        printf("  wrote                 %u bytes (%u header + %u payload)\n",
               (unsigned)DSV_SIZE, (unsigned)HDR_SIZE, (unsigned)SAV_SIZE);
        printf("  version               %u\n", (unsigned)DSV_VERSION);
        printf("  checksum              0x%04X (%u)\n", (unsigned)stored, (unsigned)stored);
    }
    free(payload);
    free(dsv);
    return ok ? 0 : 1;
}

static int mode_verify(const char *path)
{
    uint8_t *data = NULL;
    size_t len = 0;
    const uint8_t *payload;
    uint16_t stored, computed;

    if (!read_file(path, &data, &len))
        return 1;
    if (!validate_dsv(path, data, len)) {
        free(data);
        return 1;
    }
    payload = data + HDR_SIZE;
    stored = read_u16_le(data + 5);
    computed = payload_checksum(payload, SAV_SIZE);
    printf("OK: %s is a valid version-%u .dsv save\n", path, (unsigned)DSV_VERSION);
    printf("  size                  %u bytes (%u header + %u payload)\n",
           (unsigned)len, (unsigned)HDR_SIZE, (unsigned)SAV_SIZE);
    printf("  magic                 DOSV (44 4f 53 56)\n");
    printf("  version               %u\n", (unsigned)data[4]);
    printf("  checksum (stored)     0x%04X (%u)\n", (unsigned)stored, (unsigned)stored);
    printf("  checksum (recomputed) 0x%04X (%u)\n", (unsigned)computed, (unsigned)computed);
    /* Demonstrate the endian-neutral 32-bit writer so it stays compiled
     * and covered: round-trip the payload length through it. */
    {
        uint8_t tmp[4];
        write_u32_le(tmp, (uint32_t)SAV_SIZE);
        if (read_u16_le(tmp) != (uint16_t)(SAV_SIZE & 0xFFFFu)) {
            fprintf(stderr, "%s: internal error: endian helpers disagree.\n", prog);
            free(data);
            return 1;
        }
    }
    free(data);
    return 0;
}

static void usage(FILE *out)
{
    fprintf(out,
            "Usage: %s --to-sav IN.dsv OUT.sav   DOS save -> GB SRAM dump\n"
            "       %s --to-dsv IN.sav OUT.dsv   GB SRAM dump -> DOS save\n"
            "       %s --verify FILE.dsv         validate a .dsv file and print a summary\n"
            "       %s --info FILE.dsv           alias of --verify\n"
            "       %s --help                    print this usage\n",
            prog, prog, prog, prog, prog);
}

int main(int argc, char *argv[])
{
    if (argc > 0 && argv[0] != NULL) {
        const char *slash = strrchr(argv[0], '/');
#ifdef _WIN32
        {
            const char *back = strrchr(argv[0], '\\');
            if (back != NULL && (slash == NULL || back > slash))
                slash = back;
        }
#endif
        if (slash != NULL && slash[1] != '\0')
            prog = slash + 1;
    }

    if (argc == 4 && (strcmp(argv[1], "--to-sav") == 0 || strcmp(argv[1], "--to-gb") == 0))
        return mode_to_sav(argv[2], argv[3]);
    if (argc == 4 && (strcmp(argv[1], "--to-dsv") == 0 || strcmp(argv[1], "--to-dos") == 0))
        return mode_to_dsv(argv[2], argv[3]);
    if (argc == 3 && (strcmp(argv[1], "--verify") == 0 || strcmp(argv[1], "--info") == 0))
        return mode_verify(argv[2]);
    if (argc == 2 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
        usage(stdout);
        return 0;
    }

    usage(stderr);
    return 1;
}
