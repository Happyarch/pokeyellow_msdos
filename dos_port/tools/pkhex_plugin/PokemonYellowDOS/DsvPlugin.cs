// DsvPlugin — PKHeX entry point. Written against the measured PKHeX.Core 26.7.7
// API (reflection probes, 2026-09-10), not the plan's first-draft sketch:
// - IPlugin requires NotifyDisplayLanguageChanged; SaveFileEditor is get-only
//   (private setter set from Initialize args); PKMEditor is convention, not interface.
// - Menus come from the ToolStrip in Initialize args (Menu_Tools item), the pattern
//   real plugins (BulkEggGenerator, FlagsEditorEX) use. IPlugin has no menu API.
// - Export uses sav.Write() (optional BinaryExportSetting); SaveFile has no
//   SetChecksums() — Write() recomputes (verified by round-trip tests).
using System.Windows.Forms;
using PKHeX.Core;

namespace PokemonYellowDOS;

public sealed class DsvPlugin : IPlugin
{
    public string Name => "Pokémon Yellow DOS Save (.dsv)";
    public int Priority => 1;

    public ISaveFileProvider SaveFileEditor { get; private set; } = null!;
    public IPKMView PKMEditor { get; private set; } = null!;

    public void Initialize(params object[] args)
    {
        SaveFileEditor = (ISaveFileProvider)Array.Find(args, static z => z is ISaveFileProvider)!;
        PKMEditor = (IPKMView)Array.Find(args, static z => z is IPKMView)!;

        if (!SaveUtil.CustomSaveReaders.OfType<DsvSaveReader>().Any())
            SaveUtil.CustomSaveReaders.Add(new DsvSaveReader());

        if (Array.Find(args, static z => z is ToolStrip) is not ToolStrip menuStrip)
            return;
        if (menuStrip.Items.Find("Menu_Tools", false) is not [ToolStripDropDownItem tools])
            return;
        const string menuName = "Menu_PokemonYellowDOS";
        if (tools.DropDownItems.Find(menuName, false).Length != 0)
            return; // already added (re-initialize guard)
        var ourMenu = new ToolStripMenuItem("Pokémon Yellow DOS") { Name = menuName };
        ourMenu.DropDownItems.Add(new ToolStripMenuItem("Export as .dsv (DOS Port)...", null, ExportDsv));
        ourMenu.DropDownItems.Add(new ToolStripMenuItem("Export as .sav (Standard GB)...", null, ExportSav));
        tools.DropDownItems.Add(ourMenu);
    }

    public void NotifySaveLoaded() { }

    public void NotifyDisplayLanguageChanged(string language) { }

    public bool TryLoadFile(string filePath)
    {
        // DeSmuME collision guard only. OpenFromPath consults plugins BEFORE its
        // own size/content checks, so this is the one place that can intercept a
        // Nintendo DS .dsv with guidance instead of a cryptic load failure.
        // Valid DOS-port files return false: the registered DsvSaveReader loads
        // them through the normal pipeline.
        byte[] data;
        try { data = File.ReadAllBytes(filePath); }
        catch { return false; }

        if (!DsvFormat.IsDeSmuME(data))
            return false;

        MessageBox.Show(
            "This file appears to be a Nintendo DS (DeSmuME) save file.\n\n" +
            "DeSmuME and the Pokémon Yellow DOS port both use the .dsv extension, but their formats differ.\n" +
            "Please export a raw save in DeSmuME via File -> Export Backup Memory.",
            "DeSmuME Save Detected",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
        return true; // handled (rejected with guidance)
    }

    private void ExportDsv(object? sender, EventArgs e)
    {
        if (SaveFileEditor.SAV is not SAV1 sav)
        {
            MessageBox.Show("Current save is not a Generation 1 save file.", "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        byte[] payload = sav.Write().ToArray();
        if (payload.Length != DsvFormat.PayloadSize)
        {
            MessageBox.Show($"Unexpected save size {payload.Length} bytes (expected {DsvFormat.PayloadSize}).", "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        byte[] dsvData = DsvFormat.BuildDsv(payload);

        using var sfd = new SaveFileDialog
        {
            Filter = "Pokémon Yellow DOS Save (*.dsv)|*.dsv",
            FileName = "POKEMON.DSV",
            Title = "Export DOS Port Save File"
        };

        if (sfd.ShowDialog() == DialogResult.OK)
        {
            File.WriteAllBytes(sfd.FileName, dsvData);
            MessageBox.Show($"Successfully exported {dsvData.Length} bytes to {Path.GetFileName(sfd.FileName)}", "Export Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private void ExportSav(object? sender, EventArgs e)
    {
        if (SaveFileEditor.SAV is not SAV1 sav)
        {
            MessageBox.Show("Current save is not a Generation 1 save file.", "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        byte[] payload = sav.Write().ToArray();

        using var sfd = new SaveFileDialog
        {
            Filter = "Game Boy Save (*.sav)|*.sav",
            FileName = "POKEMON.SAV",
            Title = "Export Standard Game Boy Save File"
        };

        if (sfd.ShowDialog() == DialogResult.OK)
        {
            File.WriteAllBytes(sfd.FileName, payload);
            MessageBox.Show($"Successfully exported {payload.Length} bytes to {Path.GetFileName(sfd.FileName)}", "Export Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
}
