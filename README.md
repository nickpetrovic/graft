# Graft

Graft is a Mac app for managing mods in games built with [MacNativeGames](https://github.com/ly05010419/MacNativeGames). Drag mods onto the window, switch them on or off, put them in order, and press Play. Graft merges the mods, checks that their code can run on the Mac, fixes what it can, and starts the game.

![Graft](docs/media/graft-mods.png)

## Requirements

- A Mac with Apple silicon and macOS 26 or later. Graft has been tested on macOS 27.
- A game built with MacNativeGames from your own copy of the game and your own Switch's keys: Tears of the Kingdom (tested with 1.2.1 and 1.4.3) or Octopath Traveler 0.
- To build Graft: the Command Line Tools for Xcode 26 or later (`xcode-select --install`), which include Swift 6.2, and the .NET 10 SDK.

## Install

```sh
git clone <repository URL> graft
cd graft
make dotnet    # only if you don't have the .NET 10 SDK; installs it in ~/.dotnet without admin rights
make install   # builds Graft, copies it to /Applications and links the graft command into ~/.local/bin
```

To try a build without installing it, run `make run`. `make help` lists every target, and `make uninstall` removes what `make install` added.

The first build downloads the source of Graft's dependencies and their packages, so it needs an internet connection. Graft is signed without an Apple developer certificate; a copy you build yourself opens normally.

## Use

1. Open Graft and add your game: drop its app on the window, choose **Add Game…**, or click **Add…** next to it under **Found on This Mac**. Graft fills in how the game is set up from its template, or from the app and MacNativeGames, and you check it before the game is added.
2. Graft finds the game's files, your keys and your MacNativeGames folder, and offers to import an existing TKMM library. Anything it can't find is listed with a button to choose it, or to open Settings.
3. Drag mods onto the window, or click **+**. Tears of the Kingdom mods can be zip, 7z, rar or tkcl files, or folders with `romfs` or `exefs` inside. Octopath Traveler 0 mods can be `.pak` files, zip, 7z or rar files, or folders with `romfs` or `.pak` files inside.
4. Switch mods on or off and drag them into order. When two mods change the same thing, the one higher in the list wins.
5. Click **Play**.

Graft works with any game that MacNativeGames builds. It manages mods for Tears of the Kingdom and for ports that load a folder of replacement game files, such as Octopath Traveler 0. See [Games](docs/games.md) for how games are added and described.

## Documentation

- [Using Graft](docs/using.md): the mod list, badges, versions and load orders, crash reports, Game Info, Settings and the command-line tool.
- [Games](docs/games.md): adding a game, the game editor, definitions and templates, and adding mod support for a new kind of port.
- [How Graft works](docs/architecture.md): what happens when you press Play, code mods, the project layout, how the app is organized and how it talks to the merge helper.
- [Building and contributing](docs/building.md): prerequisites, scripts, running from source, tests and Graft's changes to TkSharp.
- [Contributing](docs/CONTRIBUTING.md): what to check before you send a change, the code conventions, and how to report a problem.

## License

Graft is released under the [MIT License](LICENSE). The merge helper it includes is built from TkSharp and other projects; see [Third-party notices](THIRD_PARTY_NOTICES.md).

Use Graft only with games you own, and with keys and game files from your own Nintendo Switch. Graft doesn't include or download any game content. It is an independent, non-commercial project, not affiliated with, endorsed by or sponsored by Nintendo or by the MacNativeGames project. The Legend of Zelda, Super Mario and Nintendo Switch are trademarks of Nintendo.
