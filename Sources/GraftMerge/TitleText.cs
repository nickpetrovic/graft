using MessageStudio.Formats.BinaryText;
using SarcLibrary;
using TkSharp.Core;
using TkSharp.Core.Models;

namespace GraftMerge;

public static class TitleText
{
    public static TkChangelog Create(string locale, string text, int gameVersion)
    {
        Msbt msbt = new() { ["0003"] = new MsbtEntry { Text = text } };

        using MemoryStream msbtStream = new();
        msbt.WriteBinary(msbtStream);

        Sarc sarc = new() { ["LayoutMsg/Title_00.msbt"] = msbtStream.ToArray() };
        MemoryStream sarcStream = new();
        sarc.Write(sarcStream);
        sarcStream.Position = 0;

        return new TkChangelog {
            BuilderVersion = 200,
            GameVersion = gameVersion,
            MalsFiles = { $"Mals/{locale}.Product.sarc" },
            Source = new StreamSource(sarcStream)
        };
    }

    private sealed class StreamSource(Stream stream) : ITkSystemSource
    {
        public Stream OpenRead(string path)
        {
            stream.Position = 0;
            return stream;
        }

        public bool Exists(string path) => true;

        public ITkSystemSource GetRelative(string relativePath) => this;
    }
}
