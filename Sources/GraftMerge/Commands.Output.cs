using TkSharp.Core.Models;

namespace GraftMerge;

public static partial class Commands
{
    private static ModList List(TkProfile profile) => new(Mods(profile));

    private static InstalledMod[] Mods(TkProfile profile)
    {
        return profile.Mods.Select((profileMod, position) => {
            var mod = profileMod.Mod;
            var changelogs = Changelogs(mod);
            return new InstalledMod(
                mod.Id.ToString(),
                mod.Name,
                mod.Version,
                mod.Author,
                mod.Description,
                profileMod.IsEnabled,
                position,
                changelogs.Sum(c => c.ChangelogFiles.Count),
                changelogs.Sum(c => c.MalsFiles.Count),
                changelogs.Sum(c => c.SubSdkFiles.Count),
                changelogs.Sum(c => c.CheatFiles.Count),
                changelogs.SelectMany(c => c.PatchFiles).Select(p => p.NsoBinaryId.ToLowerInvariant()).Distinct().ToArray(),
                mod.OptionGroups.Select(group => {
                    profileMod.SelectedOptions.TryGetValue(group, out var selected);
                    return new ModOptionGroup(group.Name, group.Description, group.Type.ToString(),
                        group.Options.Select(option => new ModOption(option.Id.ToString(), option.Name, option.Description,
                            selected?.Contains(option) is true)).ToArray());
                }).ToArray());
        }).ToArray();
    }
}
