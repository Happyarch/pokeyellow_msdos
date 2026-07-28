// gen_box_fixture — build a Pokemon Yellow .sav with every PC box FULL, from an
// existing real save, using PKHeX.Core so the result is a legal, correctly
// checksummed Gen-1 image rather than hand-written bytes.
//
// Deterministic by construction: no RNG anywhere, so re-running reproduces the
// file byte for byte (a golden fixture that drifts is worthless).
using PKHeX.Core;

if (args.Length < 2) { Console.Error.WriteLine("usage: gen IN.sav OUT.sav"); return 1; }

var sav = (SAV1)SaveUtil.GetSaveFile(args[0])!;
Console.WriteLine($"in : {sav.GetType().Name} {sav.Version} OT={sav.OT} TID={sav.ID32} boxes={sav.BoxCount}x{sav.BoxSlotCount}");

var learn = LearnSource1YW.Instance;
Span<ushort> moves = stackalloc ushort[4];
int made = 0;

for (int box = 0; box < sav.BoxCount; box++)
{
    for (int slot = 0; slot < sav.BoxSlotCount; slot++)
    {
        int i = box * sav.BoxSlotCount + slot;
        ushort species = (ushort)((i % 151) + 1);       // walk the whole Gen-1 dex
        byte level = (byte)(5 + (i % 96));              // 5..100, deterministic

        var pk = new PK1
        {
            Species = species,
            TID16 = sav.TID16,
            OriginalTrainerName = sav.OT,
            DV16 = (ushort)(0x1234 + i * 7),            // deterministic, all 16 bits legal
        };
        pk.CurrentLevel = level;                        // sets EXP for the growth rate

        moves.Clear();
        learn.SetEncounterMoves(species, 0, level, moves);
        pk.SetMoves(moves);
        pk.HealPP();

        pk.Nickname = SpeciesName.GetSpeciesNameGeneration(species, (int)LanguageID.English, 1);
        pk.IsNicknamed = false;

        sav.SetBoxSlotAtIndex(pk, box, slot);
        made++;
    }
}

sav.CurrentBox = 0;
var image = sav.Write().ToArray();

// --- PC-box bank checksums -------------------------------------------------
// PKHeX does not write these: it updates sMainDataCheckSum but leaves the
// bank-2/3 all-boxes and per-box checksums stale (all 14 were wrong on this
// tool's first run, while the 15th was correct).
//
// That is harmless to the GAME -- those 14 bytes are write-only in pret (0 read
// sites, vs 5 cp-compare sites for sMainDataCheckSum), and a save with all of
// them inverted loads identically in mGBA. We recompute them for the FIXTURE's
// sake: a real cartridge save always has them consistent, and an internally
// inconsistent fixture is a landmine for anything that does validate.
//
// pret CalcCheckSum's rule -- the ones' complement of the byte sum over the
// region -- with offsets from ram/sram.asm.
//
// Offsets are .sav file offsets: bank N starts at N * 0x2000; sBox1 is at the
// head of bank 2 and sBox7 at the head of bank 3, each box 0x462 bytes, with
// the all-boxes checksum immediately after the six boxes and the six per-box
// checksums after that.
const int BOX_SIZE = 0x462, BOXES_PER_BANK = 6;
static byte Sum(ReadOnlySpan<byte> s) { int t = 0; foreach (var b in s) t += b; return (byte)~t; }

foreach (int bankBase in new[] { 0x4000, 0x6000 })
{
    int allCk = bankBase + BOXES_PER_BANK * BOX_SIZE;
    image[allCk] = Sum(image.AsSpan(bankBase, allCk - bankBase));
    for (int i = 0; i < BOXES_PER_BANK; i++)
        image[allCk + 1 + i] = Sum(image.AsSpan(bankBase + i * BOX_SIZE, BOX_SIZE));
}

File.WriteAllBytes(args[1], image);
Console.WriteLine($"wrote {args[1]} ({new FileInfo(args[1]).Length} bytes), {made} mons across {sav.BoxCount} boxes");
return 0;
