// DsvSaveReader tests — integration against the real PKHeX.Core pipeline
// (SaveUtil.GetSaveFile on the stripped payload). Needs the committed fixture
// dos_port/tests/fixtures/yellow_100.sav, located by walking up from the test
// assembly (no hardcoded depth: robust to bin/ layout changes).
using PKHeX.Core;
using Xunit;
using PokemonYellowDOS;

namespace PokemonYellowDOS.Tests;

public sealed class DsvSaveReaderTests
{
    private static string FindFixture(string name)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            string candidate = Path.Combine(dir.FullName, "dos_port", "tests", "fixtures", name);
            if (File.Exists(candidate))
                return candidate;
            dir = dir.Parent;
        }
        throw new FileNotFoundException($"Fixture {name} not found above {AppContext.BaseDirectory}");
    }

    [Fact]
    public void IsRecognized_OnlyTotalSize()
    {
        var reader = new DsvSaveReader();
        Assert.True(reader.IsRecognized(DsvFormat.TotalSize));
        Assert.False(reader.IsRecognized(DsvFormat.PayloadSize));
        Assert.False(reader.IsRecognized(0));
    }

    [Fact]
    public void TryRead_RealFixture_ReturnsSAV1()
    {
        byte[] sav = File.ReadAllBytes(FindFixture("yellow_100.sav"));
        Assert.Equal(DsvFormat.PayloadSize, sav.Length);
        byte[] dsv = DsvFormat.BuildDsv(sav);

        var reader = new DsvSaveReader();
        bool ok = reader.TryRead(new Memory<byte>(dsv), out SaveFile? result, "yellow_100.dsv");

        Assert.True(ok);
        var sav1 = Assert.IsType<SAV1>(result);
        // YW, not Y: PKHeX splits Yellow by region (IsYellowJPN -> Y,
        // IsYellowINT -> YW) and this fixture is international (Japanese=false).
        Assert.Equal(GameVersion.YW, sav1.Version);
    }

    [Fact]
    public void TryRead_RawSavBytes_NotClaimed()
    {
        byte[] sav = File.ReadAllBytes(FindFixture("yellow_100.sav"));
        var reader = new DsvSaveReader();
        Assert.False(reader.TryRead(new Memory<byte>(sav), out _, "yellow_100.sav"));
    }

    [Fact]
    public void TryRead_GarbageTotalSize_NotClaimed()
    {
        var reader = new DsvSaveReader();
        Assert.False(reader.TryRead(new Memory<byte>(new byte[DsvFormat.TotalSize]), out _, "junk.dsv"));
    }

    [Fact]
    public void ExportIsIdempotent()
    {
        // SAV1.Write() normalizes box layout on write (stock PKHeX semantics —
        // measured: honest Write() of yellow_100.sav differs in 7514 bytes, and
        // a second Write() is a fixed point). So the export contract is
        // idempotence + semantic preservation, not byte identity.
        byte[] sav = File.ReadAllBytes(FindFixture("yellow_100.sav"));
        var reader = new DsvSaveReader();
        Assert.True(reader.TryRead(new Memory<byte>(DsvFormat.BuildDsv(sav)), out SaveFile? result, "rt.dsv"));
        var sav1 = (SAV1)result!;
        string ot = sav1.OT;
        int party = sav1.PartyCount;

        byte[] first = sav1.Write().ToArray();
        var reparsed = (SAV1)SaveUtil.GetSaveFile(new Memory<byte>(first), "rt.sav")!;
        byte[] second = reparsed.Write().ToArray();

        Assert.Equal(first, second);
        Assert.Equal(ot, reparsed.OT);
        Assert.Equal(party, reparsed.PartyCount);
    }

    [Fact]
    public void ReaderMatchesStockBehavior()
    {
        // The reader must add no divergence beyond what stock PKHeX itself does
        // opening the stripped payload: same bytes out as GetSaveFile+Write.
        byte[] sav = File.ReadAllBytes(FindFixture("yellow_100.sav"));
        byte[] payload = (byte[])sav.Clone();
        var reader = new DsvSaveReader();
        Assert.True(reader.TryRead(new Memory<byte>(DsvFormat.BuildDsv(sav)), out SaveFile? viaReader, "rt.dsv"));
        var stock = (SAV1)SaveUtil.GetSaveFile(new Memory<byte>(payload), "rt.sav")!;
        Assert.Equal(stock.Write().ToArray(), ((SAV1)viaReader!).Write().ToArray());
    }
}
