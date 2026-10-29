using TkSharp;
using TkSharp.Core;
using TkSharp.Core.Models;
using TkSharp.IO.Writers;
using TkSharp.Merging;

namespace GraftMerge;

public static partial class Commands
{
    private static async Task<MergeReport> Merge(Session session, TkProfile profile, string outputFolder)
    {
        foreach (var name in (string[])["romfs", "romfslite", "exefs", "cheats"]) {
            var folder = Path.Combine(outputFolder, name);
            if (Directory.Exists(folder)) {
                Directory.Delete(folder, recursive: true);
            }
        }
        Directory.CreateDirectory(outputFolder);

        var romProvider = session.RomProvider;
        StderrLogger.Event("progress", "Opening the game files");
        using var rom = romProvider.GetRom();

        var enabled = profile.Mods.Where(x => x.IsEnabled).ToArray();
        foreach (var profileMod in enabled) {
            profileMod.EnsureOptionSelection();
        }

        var targets = TkModManager.GetMergeTargets(profile, _ => true).ToArray();
        if (session.Config.TitleText is { Length: > 0 } titleText && enabled.Length > 0) {
            targets = targets.Prepend(TitleText.Create(session.Config.Language, titleText, rom.GameVersion)).ToArray();
        }

        StderrLogger.Event("progress", $"Merging {enabled.Length} {(enabled.Length == 1 ? "mod" : "mods")}");
        FolderModWriter writer = new(outputFolder);
        TkMerger merger = new(writer, rom, session.Config.Language);
        await merger.MergeAsync(targets);

        var buildId = rom.NsoBinaryId;
        bool ForThisBuild(TkPatch patch) => patch.NsoBinaryId.Equals(buildId, StringComparison.OrdinalIgnoreCase);

        var codePatches = enabled.Reverse()
            .SelectMany(profileMod => SelectedChangelogs(profileMod)
                .SelectMany(changelog => changelog.PatchFiles.Where(ForThisBuild))
                .Select(patch => new ModCodePatch(profileMod.Mod.Id.ToString(), profileMod.Mod.Name, Entries(patch))))
            .ToArray();

        var ignoredCode = enabled
            .Select(profileMod => {
                var changelogs = SelectedChangelogs(profileMod);
                return new IgnoredCode(profileMod.Mod.Id.ToString(), profileMod.Mod.Name,
                    changelogs.Sum(c => c.SubSdkFiles.Count),
                    changelogs.SelectMany(c => c.PatchFiles).Count(patch => !ForThisBuild(patch)));
            })
            .Where(ignored => ignored.SubSdkFiles > 0 || ignored.PatchesForOtherBuilds > 0)
            .ToArray();

        return new MergeReport(
            buildId.ToLowerInvariant(),
            Entries(TkPatch.CreateWithDefaults(buildId, shopParamLimit: 512)),
            codePatches,
            ignoredCode);
    }

    private static TkProfile SetupProfile(Session session, IReadOnlyList<SetupEntry> setup)
    {
        TkProfile.StateChanged -= session.Manager.Save;
        TkProfile profile = new();
        foreach (var entry in setup) {
            var mod = session.Manager.Mods.FirstOrDefault(x => x.Id.ToString().Equals(entry.Id, StringComparison.OrdinalIgnoreCase))
                ?? throw new HelperException($"The mod setup names a mod that isn't in the library ({entry.Id}). Reopen Graft and apply again.");
            TkProfileMod profileMod = new(mod) { IsEnabled = entry.Enabled };
            var choices = mod.OptionGroups
                .Where(group => entry.Options?.ContainsKey(group.Name) is true)
                .Select(group => new OptionChoice(group.Name, group.Type, entry.Options![group.Name].ToHashSet()))
                .ToList();
            ProfileEditing.Restore(profileMod, choices);
            profile.Mods.Add(profileMod);
        }

        return profile;
    }

    private static IEnumerable<TkChangelog> SelectedChangelogs(TkProfileMod profileMod)
    {
        return profileMod.SelectedOptions.Values
            .SelectMany(group => group)
            .OrderBy(option => option.Priority)
            .Select(option => option.Changelog)
            .Prepend(profileMod.Mod.Changelog);
    }

    private static PatchEntry[] Entries(TkPatch patch)
    {
        return patch.Entries.OrderBy(entry => entry.Key)
            .Select(entry => new PatchEntry(entry.Key, entry.Value.ToString("X8")))
            .ToArray();
    }
}
