using TkSharp.Core;

namespace GraftMerge;

public static partial class Commands
{
    private static CodePatchFile ReadPatch(string path)
    {
        if (!File.Exists(path)) {
            throw new HelperException($"'{path}' does not exist.");
        }

        using var stream = File.OpenRead(path);
        var patch = TkPatch.FromPchTxt(stream)
            ?? throw new HelperException($"'{Path.GetFileName(path)}' has no @nsobid line, so it isn't a code patch.");
        return new CodePatchFile(patch.NsoBinaryId.ToLowerInvariant(), Entries(patch), patch.Warnings);
    }
}
