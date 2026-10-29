using TkSharp.Core.Models;

namespace GraftMerge;

public static partial class Commands
{
    private static async Task<InstallResult> Install(Session session, TkProfile profile, string path)
    {
        var input = path.TrimEnd('/', '\\');
        if (!File.Exists(input) && !Directory.Exists(input)) {
            throw new HelperException($"'{input}' does not exist.");
        }

        if (session.Readers.GetReader(input) is not { } reader) {
            throw new HelperException($"'{Path.GetFileName(input)}' is not a mod format this helper reads (zip, rar, 7z, tkcl, or a folder with romfs or exefs).");
        }

        StderrLogger.Event("progress", $"Reading {Path.GetFileName(input)}");
        await using var stream = File.Exists(input) ? File.OpenRead(input) : null;
        var mod = await reader.ReadMod(input, stream)
            ?? throw new HelperException($"'{Path.GetFileName(input)}' could not be read as a mod: it needs a romfs or exefs folder, or a TKMM package.");

        var changelogs = Changelogs(mod);
        var files = changelogs
            .SelectMany(changelog => changelog.ChangelogFiles
                .Select(entry => (entry.Canonical, entry.Type == ChangelogEntryType.Changelog))
                .Concat(changelog.MalsFiles.Select(file => (file, true))))
            .ToArray();
        if (ModGameDetector.OtherGame(files, session.Config.OtherGames) is { } otherGame) {
            var contents = Path.Combine(session.Manager.ModsFolderPath, mod.Id.ToString());
            if (Directory.Exists(contents)) {
                Directory.Delete(contents, recursive: true);
            }

            throw new HelperException($"'{mod.Name}' is a {otherGame} mod, so it can't be added to {session.Config.GameName}.");
        }

        var existing = profile.Mods.FirstOrDefault(x => x.Mod.Id == mod.Id);
        var previous = existing?.Mod;
        var snapshot = existing is null ? null : ProfileEditing.Choices(existing);
        session.Manager.Import(mod, profile);
        var imported = profile.Mods.FirstOrDefault(x => x.Mod == mod)
            ?? throw new HelperException($"'{mod.Name}' was read but not added to the mod list.");
        if (snapshot is not null) {
            ProfileEditing.Restore(imported, snapshot);
        }
        else {
            imported.EnsureOptionSelection();
        }

        var otherCopies = mod.Name.Length == 0 ? [] : profile.Mods
            .Where(x => x != imported && x.Mod.Name == mod.Name && x.Mod.Author == mod.Author)
            .ToList();
        SortedSet<string> keptBuilds = [];
        List<string> warnings = [.. changelogs.SelectMany(c => c.PatchFiles).SelectMany(p => p.Warnings)];
        foreach (var older in otherCopies.Select(x => x.Mod).Prepend(previous).OfType<TkMod>().Where(x => x != mod)) {
            var (kept, lost) = ProfileEditing.KeepOtherBuilds(mod, older);
            keptBuilds.UnionWith(kept);
            warnings.AddRange(lost);
        }

        if (otherCopies.Count > 0) {
            StderrLogger.Event("progress", $"Replacing the other copy of {mod.Name}");
            ProfileEditing.Replace(profile, imported, otherCopies[0]);
            foreach (var other in otherCopies) {
                profile.Mods.Remove(other);
                Uninstall(session, other);
            }
        }
        SaveChecked(session);

        return new InstallResult(mod.Id.ToString(), [.. otherCopies.Select(x => x.Mod.Id.ToString())], [.. keptBuilds], warnings, Mods(profile));
    }
}
