namespace GraftMerge.Tests;

public class LibraryLockTests
{
    [Fact]
    public void OnlyOneTaskCanHoldTheLibrary()
    {
        var folder = Path.Combine(Path.GetTempPath(), $"graft-lock-{Guid.NewGuid():N}");
        try {
            using (LibraryLock.Acquire(folder, TimeSpan.Zero)) {
                var error = Assert.Throws<HelperException>(() => LibraryLock.Acquire(folder, TimeSpan.FromMilliseconds(300)));
                Assert.Contains("Another Graft task", error.Message);
            }

            using var again = LibraryLock.Acquire(folder, TimeSpan.Zero);
        }
        finally {
            Directory.Delete(folder, recursive: true);
        }
    }
}
