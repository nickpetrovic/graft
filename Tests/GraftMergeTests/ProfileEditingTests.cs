using TkSharp.Core;
using TkSharp.Core.Models;

namespace GraftMerge.Tests;

public class ProfileEditingTests
{
    private static TkModOptionGroup Group(string name, OptionGroupType type, params string[] options)
    {
        TkModOptionGroup group = new() { Name = name, Type = type };
        foreach (var option in options) {
            group.Options.Add(new TkModOption { Name = option });
        }

        return group;
    }

    private static TkProfileMod Mod(string name, params TkModOptionGroup[] groups)
    {
        TkMod mod = new() { Name = name };
        foreach (var group in groups) {
            mod.OptionGroups.Add(group);
        }

        return new TkProfileMod(mod);
    }

    private static TkChangelog Code(params string[] builds)
    {
        TkChangelog changelog = new() { BuilderVersion = 0, GameVersion = 0 };
        foreach (var build in builds) {
            TkPatch patch = new(build);
            patch.Entries[0x100] = 0xD503201F;
            changelog.PatchFiles.Add(patch);
        }

        return changelog;
    }

    private static string[] Builds(TkChangelog changelog) => changelog.PatchFiles.Select(p => p.NsoBinaryId).Order(StringComparer.Ordinal).ToArray();

    private static string[] Selected(TkProfileMod mod, int group) =>
        mod.SelectedOptions.TryGetValue(mod.Mod.OptionGroups[group], out var selected) ? selected.Select(o => o.Name).Order().ToArray() : [];

    [Fact]
    public void PositionsOutsideTheListAreClamped()
    {
        TkProfile profile = new();
        var a = Mod("A");
        var b = Mod("B");
        var c = Mod("C");
        profile.Mods.Add(a);
        profile.Mods.Add(b);
        profile.Mods.Add(c);

        ProfileEditing.Move(profile, a, 99);
        Assert.Equal(["B", "C", "A"], profile.Mods.Select(m => m.Mod.Name));
        ProfileEditing.Move(profile, a, -5);
        Assert.Equal(["A", "B", "C"], profile.Mods.Select(m => m.Mod.Name));
    }

    [Theory]
    [InlineData(new[] { "New", "X", "Old", "Y" }, new[] { "X", "New", "Y" })]
    [InlineData(new[] { "X", "Old", "Y", "New" }, new[] { "X", "New", "Y" })]
    public void ANewCopyTakesTheOlderCopysPlace(string[] before, string[] after)
    {
        TkProfile profile = new();
        foreach (var name in before) {
            profile.Mods.Add(Mod(name));
        }
        var older = profile.Mods.Single(m => m.Mod.Name == "Old");
        older.IsEnabled = false;
        var added = profile.Mods.Single(m => m.Mod.Name == "New");

        ProfileEditing.Replace(profile, added, older);

        Assert.Equal(after, profile.Mods.Select(m => m.Mod.Name));
        Assert.False(added.IsEnabled);
    }

    [Fact]
    public void ChoicesCarryOverToANewCopyByName()
    {
        var older = Mod("Mod", Group("Bloom", OptionGroupType.SingleRequired, "Off", "On"), Group("Extras", OptionGroupType.Multi, "Hats", "Capes"));
        older.EnsureOptionSelection();
        older.SelectedOptions[older.Mod.OptionGroups[0]] = [older.Mod.OptionGroups[0].Options[1]];
        older.SelectedOptions[older.Mod.OptionGroups[1]] = [older.Mod.OptionGroups[1].Options[1]];

        var newer = Mod("Mod", Group("Bloom", OptionGroupType.SingleRequired, "Off", "On"), Group("Extras", OptionGroupType.Multi, "Hats"));
        newer.EnsureOptionSelection();
        ProfileEditing.Restore(newer, ProfileEditing.Choices(older));

        Assert.Equal(["On"], Selected(newer, 0));
        Assert.Empty(Selected(newer, 1));
    }

    [Fact]
    public void ANewCopyKeepsTheOlderCopysCodeForOtherBuilds()
    {
        TkMod older = new() { Name = "Mod", Changelog = Code("aaaa1111", "bbbb2222") };
        TkMod added = new() { Name = "Mod", Changelog = Code("BBBB2222", "cccc3333") };
        var newPatch = added.Changelog.PatchFiles[0];

        var (kept, warnings) = ProfileEditing.KeepOtherBuilds(added, older);

        Assert.Equal(["aaaa1111"], kept);
        Assert.Empty(warnings);
        Assert.Equal(["BBBB2222", "aaaa1111", "cccc3333"], Builds(added.Changelog));
        Assert.Contains(newPatch, added.Changelog.PatchFiles);
    }

    [Fact]
    public void OptionCodeMovesToTheOptionWithTheSameName()
    {
        var olderMod = Mod("Mod", Group("FPS", OptionGroupType.SingleRequired, "30", "60"));
        var addedMod = Mod("Mod", Group("FPS", OptionGroupType.SingleRequired, "60"));
        var older = olderMod.Mod;
        var added = addedMod.Mod;
        older.Changelog = Code();
        added.Changelog = Code();
        older.OptionGroups[0].Options[0].Changelog = Code("aaaa1111");
        older.OptionGroups[0].Options[1].Changelog = Code("aaaa1111");
        added.OptionGroups[0].Options[0].Changelog = Code("cccc3333");

        var (kept, warnings) = ProfileEditing.KeepOtherBuilds(added, older);

        Assert.Equal(["aaaa1111"], kept);
        Assert.Equal(["aaaa1111", "cccc3333"], Builds(added.OptionGroups[0].Options[0].Changelog));
        Assert.Contains("FPS: 30", Assert.Single(warnings));
    }
}
