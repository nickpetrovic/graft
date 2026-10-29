using System.Text;
using TkSharp.Core;

namespace GraftMerge.Tests;

public class TkPatchTests
{
    private const string BuildId = "9b4e43650501a4d4489b4bbfdb740f26af3cf850";

    private static TkPatch Pchtxt(string text) =>
        TkPatch.FromPchTxt(new MemoryStream(Encoding.UTF8.GetBytes(text))) ?? throw new InvalidOperationException("no patch");

    private static TkPatch Ips(params byte[][] parts) =>
        TkPatch.FromIps(new MemoryStream(parts.SelectMany(x => x).ToArray()), BuildId) ?? throw new InvalidOperationException("no patch");

    [Fact]
    public void DisabledSectionsAreSkipped()
    {
        var patch = Pchtxt($"@nsobid-{BuildId.ToUpperInvariant()}\n@flag offset_shift 0x100\n@enabled\n00001000 1F2003D5\n@disabled\n00002000 C0035FD6\n@enabled\n00003000 00008052\n@stop\n00004000 00008052\n");
        Assert.Equal(BuildId, patch.NsoBinaryId);
        Assert.Equal(new Dictionary<uint, uint> { [0x1000] = 0x1F2003D5, [0x3000] = 0x00008052 }, patch.Entries);
        Assert.Empty(patch.Warnings);
    }

    [Fact]
    public void LongValuesBecomeWordsAndPartialWordsAreReported()
    {
        var patch = Pchtxt($"@nsobid-{BuildId}0000000000000000000000000 // 1.2.1\n@flag offset_shift 0x100\n@enabled\n00001000 1F2003D5C0035FD6 // two\n00002000 0102\n00003000 \"text\"\n");
        Assert.Equal(BuildId, patch.NsoBinaryId);
        Assert.Equal(new Dictionary<uint, uint> { [0x1000] = 0x1F2003D5, [0x1004] = 0xC0035FD6 }, patch.Entries);
        Assert.Equal(2, patch.Warnings.Count);
    }

    [Theory]
    [InlineData("code-cave.pchtxt", 11)]
    [InlineData("code-cave-fixed.pchtxt", 8)]
    [InlineData("nops.pchtxt", 3)]
    public async Task CodePatchFilesAreReadWithoutWarnings(string file, int entries)
    {
        var result = await Commands.Run("read-patch", [Path.Combine(AppContext.BaseDirectory, "Fixtures", file)], new HelperConfig("/tmp/graft-tests"));

        var patch = Assert.IsType<CodePatchFile>(result);
        Assert.Equal(BuildId, patch.BuildId);
        Assert.Equal(entries, patch.Entries.Count);
        Assert.Empty(patch.Warnings);
    }

    [Fact]
    public void LinesBeforeTheBuildIdAreIgnored()
    {
        var patch = Pchtxt($"@enabled\n00001100 1F2003D5\n@nsobid-{BuildId}\n@enabled\n00002100 C0035FD6\n");
        Assert.Equal(new Dictionary<uint, uint> { [0x2000] = 0xC0035FD6 }, patch.Entries);
    }

    [Fact]
    public void MissingOffsetShiftMeansFileOffsets()
    {
        var patch = Pchtxt($"@nsobid-{BuildId}\n@enabled\n00001100 1F2003D5\n");
        Assert.Equal(new Dictionary<uint, uint> { [0x1000] = 0x1F2003D5 }, patch.Entries);
    }

    [Fact]
    public void Ips32RecordsOfAnySizeAreRead()
    {
        var patch = Ips(
            "IPS32"u8.ToArray(),
            [0x00, 0x00, 0x11, 0x00, 0x00, 0x08, 0x1F, 0x20, 0x03, 0xD5, 0xC0, 0x03, 0x5F, 0xD6],
            [0x00, 0x00, 0x21, 0x00, 0x00, 0x02, 0xAA, 0xBB],
            [0x00, 0x00, 0x31, 0x00, 0x00, 0x04, 0x00, 0x00, 0x80, 0x52],
            [0x00, 0x00, 0x41, 0x00, 0x00, 0x00, 0x00, 0x04, 0xFF],
            "EEOF"u8.ToArray());
        Assert.Equal(new Dictionary<uint, uint> {
            [0x1000] = 0x1F2003D5,
            [0x1004] = 0xC0035FD6,
            [0x3000] = 0x00008052,
            [0x4000] = 0xFFFFFFFF
        }, patch.Entries);
        Assert.Single(patch.Warnings);
    }

    [Fact]
    public void PlainIpsIsRead()
    {
        var patch = Ips("PATCH"u8.ToArray(), [0x00, 0x11, 0x00, 0x00, 0x04, 0x1F, 0x20, 0x03, 0xD5], "EOF"u8.ToArray());
        Assert.Equal(new Dictionary<uint, uint> { [0x1000] = 0x1F2003D5 }, patch.Entries);
        Assert.Empty(patch.Warnings);
    }

    [Fact]
    public void WrittenIpsReadsBack()
    {
        var patch = Pchtxt($"@nsobid-{BuildId}\n@flag offset_shift 0x100\n@enabled\n00001000 1F2003D5\n");
        using MemoryStream output = new();
        patch.WriteIps(output);
        output.Position = 0;
        Assert.Equal(patch.Entries, TkPatch.FromIps(output, BuildId)!.Entries);
    }
}
