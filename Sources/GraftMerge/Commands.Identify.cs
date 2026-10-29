using LibHac.FsSystem;
using TkSharp.Extensions.LibHac.Extensions;
using TkSharp.Extensions.LibHac.Util;

namespace GraftMerge;

public static partial class Commands
{
    private static UpdateList IdentifyUpdates(HelperConfig config, IEnumerable<string> paths)
    {
        if (config.KeysFolder.Length == 0) {
            throw new HelperException("Choose the keys folder in Graft's Settings first, so update files can be read.");
        }

        var keys = TkKeyUtils.GetKeysFromFolder(config.KeysFolder)
            ?? throw new HelperException($"There is no prod.keys in '{config.KeysFolder}', so update files can't be read.");
        List<UpdateFile> updates = [];
        foreach (var path in paths.Where(File.Exists)) {
            try {
                using LocalStorage storage = new(path, FileAccess.Read);
                using var files = storage.GetSwitchFs(path, keys);
                updates.AddRange(files.Applications.Values
                    .Where(application => application.Patch is not null)
                    .Select(application => new UpdateFile(path, application.TitleId.ToString("X16"), application.DisplayVersion)));
            }
            catch (Exception ex) when (ex is not HelperException) {
                StderrLogger.Event("progress", $"Skipped {Path.GetFileName(path)}: {ex.Message}");
            }
        }

        return new UpdateList(updates);
    }
}
