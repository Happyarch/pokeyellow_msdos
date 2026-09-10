// DsvFormat unit tests — hermetic vectors (no fixtures, no PKHeX dependency).
using Xunit;
using PokemonYellowDOS;

namespace PokemonYellowDOS.Tests;

public sealed class DsvFormatTests
{
    [Fact]
    public void Checksum_Empty_IsZero()
    {
        Assert.Equal((ushort)0, DsvFormat.ComputeChecksum(ReadOnlySpan<byte>.Empty));
    }

    [Fact]
    public void Checksum_SmallVector_AddsBytes()
    {
        Assert.Equal((ushort)6, DsvFormat.ComputeChecksum(new byte[] { 1, 2, 3 }));
        Assert.Equal((ushort)0x01FE, DsvFormat.ComputeChecksum(new byte[] { 0xFF, 0xFF }));
    }

    [Fact]
    public void Checksum_WrapsModulo65536()
    {
        // 300 * 0xFF = 76500; 76500 - 65536 = 10964 = 0x2AD4.
        var payload = new byte[300];
        Array.Fill(payload, (byte)0xFF);
        Assert.Equal((ushort)0x2AD4, DsvFormat.ComputeChecksum(payload));
    }

    [Fact]
    public void BuildDsv_Layout_MagicVersionChecksumPayload()
    {
        var payload = new byte[DsvFormat.PayloadSize];
        for (int i = 0; i < payload.Length; i++)
            payload[i] = (byte)(i & 0xFF);

        byte[] dsv = DsvFormat.BuildDsv(payload);

        Assert.Equal(DsvFormat.TotalSize, dsv.Length); // 32775
        Assert.Equal((byte)'D', dsv[0]);
        Assert.Equal((byte)'O', dsv[1]);
        Assert.Equal((byte)'S', dsv[2]);
        Assert.Equal((byte)'V', dsv[3]);
        Assert.Equal((byte)2, dsv[4]);
        ushort stored = (ushort)(dsv[5] | (dsv[6] << 8));
        Assert.Equal(DsvFormat.ComputeChecksum(payload), stored);
        Assert.Equal(payload, dsv.AsSpan(DsvFormat.HeaderSize..).ToArray());
    }

    [Fact]
    public void RoundTrip_ExtractPayload_ReturnsOriginal()
    {
        var payload = new byte[DsvFormat.PayloadSize];
        new Random(42).NextBytes(payload);
        Assert.Equal(payload, DsvFormat.ExtractPayload(DsvFormat.BuildDsv(payload)));
    }

    [Fact]
    public void IsDsv_AcceptsOwnOutput()
    {
        var payload = new byte[DsvFormat.PayloadSize];
        new Random(7).NextBytes(payload);
        Assert.True(DsvFormat.IsDsv(DsvFormat.BuildDsv(payload)));
    }

    [Fact]
    public void IsDsv_RejectsRawSavSize()
    {
        Assert.False(DsvFormat.IsDsv(new byte[DsvFormat.PayloadSize]));
    }

    [Fact]
    public void IsDsv_RejectsBadMagic()
    {
        byte[] dsv = DsvFormat.BuildDsv(new byte[DsvFormat.PayloadSize]);
        dsv[0] = (byte)'X';
        Assert.False(DsvFormat.IsDsv(dsv));
    }

    [Fact]
    public void IsDsv_RejectsBadVersion()
    {
        byte[] dsv = DsvFormat.BuildDsv(new byte[DsvFormat.PayloadSize]);
        dsv[4] = 0x01;
        Assert.False(DsvFormat.IsDsv(dsv));
    }

    [Fact]
    public void IsDsv_RejectsBadChecksum()
    {
        byte[] dsv = DsvFormat.BuildDsv(new byte[DsvFormat.PayloadSize]);
        dsv[DsvFormat.HeaderSize] ^= 0xFF; // corrupt first payload byte
        Assert.False(DsvFormat.IsDsv(dsv));
    }

    [Fact]
    public void IsDeSmuME_DetectsCookie()
    {
        var data = new byte[100];
        "|-DESMUME SAVE-|"u8.CopyTo(data.AsSpan(100 - 16));
        Assert.True(DsvFormat.IsDeSmuME(data));
    }

    [Fact]
    public void IsDeSmuME_RejectsShortAndClean()
    {
        Assert.False(DsvFormat.IsDeSmuME(new byte[15]));
        Assert.False(DsvFormat.IsDeSmuME(new byte[32775]));
        Assert.False(DsvFormat.IsDsv(new byte[32775])); // zeroed 32775: bad magic
    }
}
