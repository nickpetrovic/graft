using TkSharp.Core;
using TkSharp.Core.Models;

namespace GraftMerge;

public sealed record OptionChoice(string Group, OptionGroupType Type, HashSet<string> Options);

public static class ProfileEditing
{
    public static void Move(TkProfile profile, TkProfileMod target, int position)
    {
        var from = profile.Mods.IndexOf(target);
        var to = Math.Clamp(position, 0, profile.Mods.Count - 1);
        if (from != to) {
            profile.Mods.Move(from, to);
        }
    }

    public static void Replace(TkProfile profile, TkProfileMod added, TkProfileMod older)
    {
        if (added == older) {
            throw new HelperException("A mod can't replace itself.");
        }

        added.IsEnabled = older.IsEnabled;
        Restore(added, Choices(older));
        var position = profile.Mods.IndexOf(older);
        profile.Mods.Remove(older);
        Move(profile, added, profile.Mods.IndexOf(added) < position ? position - 1 : position);
    }

    public static (IReadOnlyList<string> Kept, IReadOnlyList<string> Warnings) KeepOtherBuilds(TkMod added, TkMod older)
    {
        var covered = Changelogs(added).SelectMany(c => c.PatchFiles).Select(BuildId).ToHashSet();
        SortedSet<string> kept = [];
        List<string> warnings = [];
        foreach (var (from, to, where) in Pairs(added, older)) {
            foreach (var patch in from?.PatchFiles.Where(p => !covered.Contains(BuildId(p))) ?? []) {
                if (to is null) {
                    warnings.Add($"the older copy's code for build {BuildId(patch)[..8]} belongs to {where}, which the new copy doesn't have");
                    continue;
                }

                to.PatchFiles.Add(patch);
                kept.Add(BuildId(patch));
            }
        }

        return ([.. kept], warnings);
    }

    private static IEnumerable<(TkChangelog? From, TkChangelog? To, string Where)> Pairs(TkMod added, TkMod older)
    {
        yield return (older.Changelog, added.Changelog, "the mod");
        foreach (var group in older.OptionGroups) {
            foreach (var option in group.Options) {
                var match = added.OptionGroups.FirstOrDefault(g => g.Name == group.Name)?.Options.FirstOrDefault(o => o.Name == option.Name);
                yield return (option.Changelog, match?.Changelog, $"the option '{group.Name}: {option.Name}'");
            }
        }
    }

    private static IEnumerable<TkChangelog> Changelogs(TkMod mod) =>
        mod.OptionGroups.SelectMany(g => g.Options).Select(o => o.Changelog).Prepend(mod.Changelog).Where(c => c is not null);

    private static string BuildId(TkPatch patch) => patch.NsoBinaryId.ToLowerInvariant();

    public static List<OptionChoice> Choices(TkProfileMod mod)
    {
        return mod.SelectedOptions
            .Select(x => new OptionChoice(x.Key.Name, x.Key.Type, x.Value.Select(o => o.Name).ToHashSet()))
            .ToList();
    }

    public static void Restore(TkProfileMod target, IReadOnlyList<OptionChoice> choices)
    {
        var current = target.Mod.OptionGroups.ToDictionary(g => g,
            g => target.SelectedOptions.TryGetValue(g, out var selected) ? selected : []);
        foreach (var group in target.Mod.OptionGroups) {
            if (choices.FirstOrDefault(x => x.Group == group.Name && x.Type == group.Type) is not { } old) {
                continue;
            }

            var carried = group.Options.Where(o => old.Options.Contains(o.Name)).ToHashSet();
            if ((IsRequired(group) && carried.Count == 0) || (IsSingle(group) && carried.Count > 1)) {
                continue;
            }

            current[group] = carried;
        }

        target.SelectedOptions = current.Where(x => x.Value.Count > 0).ToDictionary(x => x.Key, x => x.Value);
        target.EnsureOptionSelection();
    }

    private static bool IsSingle(TkModOptionGroup group) => group.Type is OptionGroupType.Single or OptionGroupType.SingleRequired;

    private static bool IsRequired(TkModOptionGroup group) => group.Type is OptionGroupType.SingleRequired or OptionGroupType.MultiRequired;
}
