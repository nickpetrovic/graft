namespace GraftMerge;

public static class LibraryLock
{
    public static FileStream Acquire(string dataFolder, TimeSpan wait)
    {
        Directory.CreateDirectory(dataFolder);
        var path = Path.Combine(dataFolder, "library.lock");
        var deadline = DateTime.UtcNow + wait;
        while (true) {
            try {
                return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            }
            catch (IOException) when (DateTime.UtcNow < deadline) {
                Thread.Sleep(100);
            }
            catch (IOException) {
                throw new HelperException("Another Graft task is still changing this game's mods. Try again when it finishes.");
            }
        }
    }
}
