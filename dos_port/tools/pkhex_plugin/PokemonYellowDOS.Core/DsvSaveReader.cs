// DsvSaveReader — the load path. Registered into SaveUtil.CustomSaveReaders by
// DsvPlugin.Initialize, so PKHeX's normal FileUtil.GetSupportedFile pipeline opens
// POKEMON.DSV natively (backups, title, editors — everything stock PKHeX does).
//
// Why a reader instead of TryLoadFile interception (the plan's first draft):
// ISaveFileProvider.SAV is get-only, so a plugin cannot hand a parsed save to the
// app from TryLoadFile; and IPlugin has no menu API (GetActionButtons was removed
// upstream — menus come from Initialize args). The reader hook is the sanctioned
// custom-format path: SaveUtil.TryGetSaveFile consults CustomSaveReaders, and our
// reader only claims 32775-byte files with valid DOSV magic + version + checksum,
// so the SaveHandlerFooterRTC trap (size & 0x3F == 7) never sees them mangled.
using System.Diagnostics.CodeAnalysis;
using PKHeX.Core;

namespace PokemonYellowDOS;

public sealed class DsvSaveReader : ISaveReader
{
    public bool IsRecognized(long dataLength) => dataLength == DsvFormat.TotalSize;

    public bool TryRead(Memory<byte> data, [NotNullWhen(true)] out SaveFile? result, string? path = null)
    {
        result = null;
        if (data.Length != DsvFormat.TotalSize)
            return false;
        if (!DsvFormat.IsDsv(data.Span))
            return false;

        var payload = DsvFormat.ExtractPayload(data.Span);
        SaveFile? sav;
        try
        {
            // Reuse PKHeX's own Gen-1 detection for the stripped payload, so
            // language/version handling matches opening a raw .sav exactly.
            // NOTE: SaveFile aliases its input buffer (Buffer = data) and
            // Write() mutates it in place (checksums + box merge). The payload
            // here is a fresh copy per call, so no caller state is at risk —
            // but never pass a buffer you need pristine into GetSaveFile.
            sav = SaveUtil.GetSaveFile(new Memory<byte>(payload), path);
        }
        catch
        {
            return false;
        }
        if (sav is not SAV1)
            return false;
        result = sav;
        return true;
    }
}
