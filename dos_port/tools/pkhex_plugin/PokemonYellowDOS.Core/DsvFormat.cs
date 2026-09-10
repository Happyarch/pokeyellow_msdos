// DsvFormat — header build / validate / strip / checksum for the DOS port .dsv v2.
// Pure logic, no PKHeX dependency: mirrors dsv2sav.c and dsv_io.asm:SramLoadImage
// validation order (DeSmuME probe -> size -> magic -> version -> checksum).
namespace PokemonYellowDOS;

public static class DsvFormat
{
    public const int HeaderSize = 7;
    public const int PayloadSize = 32768;
    public const int TotalSize = HeaderSize + PayloadSize;
    public const byte Version = 2;
    private static readonly byte[] MagicBytes = "DOSV"u8.ToArray();
    private static readonly byte[] DeSmuMECookie = "|-DESMUME SAVE-|"u8.ToArray();

    public static bool IsDeSmuME(ReadOnlySpan<byte> data)
    {
        return data.Length >= 16 && data[^16..].SequenceEqual(DeSmuMECookie);
    }

    public static bool IsDsv(ReadOnlySpan<byte> data)
    {
        if (data.Length != TotalSize)
            return false;
        if (!data[..4].SequenceEqual(MagicBytes))
            return false;
        if (data[4] != Version)
            return false;

        ushort stored = (ushort)(data[5] | (data[6] << 8));
        ushort computed = ComputeChecksum(data[HeaderSize..]);
        return stored == computed;
    }

    public static ushort ComputeChecksum(ReadOnlySpan<byte> payload)
    {
        int sum = 0;
        foreach (byte b in payload)
            sum += b;
        return (ushort)(sum & 0xFFFF);
    }

    public static byte[] BuildDsv(ReadOnlySpan<byte> payload)
    {
        var dsv = new byte[TotalSize];
        MagicBytes.CopyTo(dsv, 0);
        dsv[4] = Version;
        ushort checksum = ComputeChecksum(payload);
        dsv[5] = (byte)(checksum & 0xFF);
        dsv[6] = (byte)((checksum >> 8) & 0xFF);
        payload.CopyTo(dsv.AsSpan(HeaderSize));
        return dsv;
    }

    public static byte[] ExtractPayload(ReadOnlySpan<byte> dsv)
    {
        return dsv[HeaderSize..].ToArray();
    }
}
