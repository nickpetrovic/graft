using TkSharp.Core.Models;

namespace GraftMerge;

public static partial class Commands
{
    public static async Task<object> Run(string command, string[] arguments, HelperConfig config)
    {
        if (command == "read-patch") {
            return ReadPatch(Argument(arguments, 0, "a .pchtxt file"));
        }

        if (command == "identify-updates") {
            return IdentifyUpdates(config, arguments);
        }

        using var exclusive = LibraryLock.Acquire(config.DataFolder, TimeSpan.FromSeconds(30));
        Session session = new(config);
        var profile = session.Manager.GetCurrentProfile();

        switch (command) {
            case "list":
                return List(profile);
            case "install":
                return await Install(session, profile, Argument(arguments, 0, "a mod file or folder"));
            case "uninstall":
                Uninstall(session, FindMod(profile, Argument(arguments, 0, "a mod id")));
                return Save(session, profile);
            case "merge":
                return await Merge(session, SetupProfile(session, config.Setup
                    ?? throw new HelperException("The merge needs the mod setup for this game version.")), Argument(arguments, 0, "an output folder"));
            default:
                throw new HelperException($"Unknown command '{command}'.");
        }
    }

    private static ModList Save(Session session, TkProfile profile)
    {
        SaveChecked(session);
        return List(profile);
    }

    private static void SaveChecked(Session session)
    {
        var stateFile = Path.Combine(session.Manager.DataFolderPath, "state.db");
        var before = File.Exists(stateFile) ? File.GetLastWriteTimeUtc(stateFile) : DateTime.MinValue;
        session.Manager.Save();
        if (!File.Exists(stateFile) || File.GetLastWriteTimeUtc(stateFile) == before) {
            throw new HelperException($"The mod list couldn't be saved. {StderrLogger.LastWarning ?? StderrLogger.FirstError}".TrimEnd());
        }
    }

    private static void Uninstall(Session session, TkProfileMod target)
    {
        session.Manager.Uninstall(target.Mod);
        if (session.Manager.Mods.Contains(target.Mod)) {
            throw new HelperException($"'{target.Mod.Name}' couldn't be removed. {StderrLogger.FirstError}".TrimEnd());
        }
    }

    private static string Argument(string[] arguments, int index, string what)
    {
        if (arguments.Length <= index) {
            throw new HelperException($"Missing argument: {what}.");
        }

        return arguments[index];
    }

    private static TkProfileMod FindMod(TkProfile profile, string id)
    {
        return profile.Mods.FirstOrDefault(x => x.Mod.Id.ToString().Equals(id, StringComparison.OrdinalIgnoreCase))
            ?? throw new HelperException($"No installed mod has the id '{id}'.");
    }

    private static TkChangelog[] Changelogs(TkMod mod)
    {
        TkChangelog[] all = [mod.Changelog, .. mod.OptionGroups.SelectMany(group => group.Options).Select(option => option.Changelog)];
        return [.. all.Where(changelog => changelog is not null)];
    }
}
