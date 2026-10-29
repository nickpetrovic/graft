using System.Text.Json.Serialization;

namespace GraftMerge;

public sealed record ModList(IReadOnlyList<InstalledMod> Mods);

public sealed record InstallResult(string Installed, IReadOnlyList<string> ReplacedIds, IReadOnlyList<string> KeptCodeBuilds, IReadOnlyList<string> Warnings, IReadOnlyList<InstalledMod> Mods);

public sealed record SetupEntry(string Id, bool Enabled, IReadOnlyDictionary<string, IReadOnlyList<string>>? Options);

public sealed record InstalledMod(
    string Id,
    string Name,
    string Version,
    string Author,
    string Description,
    bool Enabled,
    int Position,
    int DataFiles,
    int TextFiles,
    int SubSdkFiles,
    int CheatFiles,
    IReadOnlyList<string> CodePatchBuilds,
    IReadOnlyList<ModOptionGroup> OptionGroups);

public sealed record ModOptionGroup(string Name, string Description, string Type, IReadOnlyList<ModOption> Options);

public sealed record ModOption(string Id, string Name, string Description, bool Selected);

public sealed record MergeReport(
    string BuildId,
    IReadOnlyList<PatchEntry> DefaultPatches,
    IReadOnlyList<ModCodePatch> CodePatches,
    IReadOnlyList<IgnoredCode> IgnoredCode);

public sealed record PatchEntry(uint Address, string Bytes);

public sealed record ModCodePatch(string ModId, string ModName, IReadOnlyList<PatchEntry> Entries);

public sealed record IgnoredCode(string ModId, string ModName, int SubSdkFiles, int PatchesForOtherBuilds);

public sealed record CodePatchFile(string BuildId, IReadOnlyList<PatchEntry> Entries, IReadOnlyList<string> Warnings);

public sealed record UpdateList(IReadOnlyList<UpdateFile> Updates);

public sealed record UpdateFile(string Path, string TitleId, string DisplayVersion);

public sealed record HelperFailure(string Error);

public sealed record HelperEvent(string Event, string Message);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(HelperConfig))]
[JsonSerializable(typeof(ModList))]
[JsonSerializable(typeof(InstallResult))]
[JsonSerializable(typeof(MergeReport))]
[JsonSerializable(typeof(CodePatchFile))]
[JsonSerializable(typeof(UpdateList))]
[JsonSerializable(typeof(HelperFailure))]
[JsonSerializable(typeof(HelperEvent))]
public sealed partial class HelperJson : JsonSerializerContext;
