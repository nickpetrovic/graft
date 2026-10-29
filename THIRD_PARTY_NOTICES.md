# Third-party notices

Graft's own code is released under the MIT License (see [LICENSE](LICENSE)). The app also contains code from the projects below.

## Graft app and command-line tool

| Component | License | Source |
| :-- | :-- | :-- |
| Capstone 5.0.9 (core and ARM64 disassembler) | BSD-3-Clause; the ARM64 parts derived from LLVM are under the LLVM license | https://github.com/capstone-engine/capstone |

## Merge helper (graft-merge)

`graft-merge` is a separate program inside the app, built from `Sources/GraftMerge` with the .NET 10 runtime included. It contains TkSharp and the packages TkSharp uses:

| Component | Version | License | Source |
| :-- | :-- | :-- | :-- |
| TkSharp (with the changes in `vendor/patches/`) | submodule `vendor/TkSharp` | MIT | https://github.com/TKMM-Team/TkSharp |
| .NET runtime | 10 | MIT, with the notices in https://github.com/dotnet/runtime/blob/main/THIRD-PARTY-NOTICES.TXT | https://github.com/dotnet/runtime |
| BfresLibrary | 1.6.0 | MIT | https://github.com/KillzXGaming/BfresLibrary |
| BsDiff | 1.1.0 | MIT | https://github.com/LogosBible/bsdiff.net |
| CommunityToolkit.HighPerformance | 8.4.0 | MIT | https://github.com/CommunityToolkit/dotnet |
| CommunityToolkit.Mvvm | 8.4.0 | MIT | https://github.com/CommunityToolkit/dotnet |
| Humanizer | 3.0.1 | MIT | https://github.com/Humanizr/Humanizer |
| Humanizer.Core (and its language packs) | 3.0.1 | MIT | https://github.com/Humanizr/Humanizer |
| LanguageExt.Core | 4.4.9 | MIT | https://github.com/louthy/language-ext |
| MessageStudio | 1.1.1 | AGPL-3.0-or-later | https://github.com/EPD-Libraries/MessageStudio |
| Microsoft.Bcl.AsyncInterfaces | 7.0.0 | MIT | https://dot.net/ |
| Microsoft.Extensions.DependencyInjection.Abstractions | 10.0.3 | MIT | https://dot.net/ |
| Microsoft.Extensions.Logging.Abstractions | 10.0.3 | MIT | https://dot.net/ |
| Newtonsoft.Json | 13.0.3 | MIT | https://www.newtonsoft.com/json |
| Revrs | 2.1.1 | MIT | https://github.com/ArchLeaders/Revrs |
| RstbLibrary | 1.0.2 | MIT | https://github.com/EPD-Libraries/RstbLibrary |
| Ryujinx.LibHac | 0.20.0 | MIT | https://git.ryujinx.app/ryubing/libhac |
| SarcLibrary | 3.3.4 | AGPL-3.0-or-later | https://github.com/EPD-Libraries/SarcLibrary |
| SharpCompress | 0.49.1 | MIT | https://github.com/adamhathcock/sharpcompress |
| SharpZipLib | 1.4.2 | MIT | https://github.com/icsharpcode/SharpZipLib |
| System.IO.Hashing | 10.0.3 | MIT | https://dot.net/ |
| Tkmm.BymlLibrary | 1.2.3 | AGPL-3.0-or-later | https://github.com/TKMM-Team/Tkmm.BymlLibrary |
| Ulid | 1.4.1 | MIT | https://github.com/Cysharp/Ulid |
| VYaml | 0.28.1 | MIT | https://github.com/hadashiA/VYaml |
| VYaml.Annotations | 0.28.1 | MIT | https://github.com/hadashiA/VYaml |
| ZstdSharp.Port | 0.8.7 | MIT | https://github.com/oleg-st/ZstdSharp |

MessageStudio, SarcLibrary and Tkmm.BymlLibrary are licensed under the GNU Affero General Public License, version 3 or later. Because `graft-merge` includes them, `graft-merge` as built is distributed under the terms of that license. Its source code is available as follows: Graft's helper is in `Sources/GraftMerge` and Graft's changes to TkSharp are in `vendor/patches/` in this repository; TkSharp is the `vendor/TkSharp` submodule; the other libraries are at the links above. The text of the license is in `Resources/Licenses/AGPL-3.0.txt`.

Graft's license is in the app's `Contents/Resources` folder. `Contents/Resources/Licenses` holds the licenses of TkSharp and Capstone, the AGPL-3.0, the .NET runtime's license and third-party notices, and `graft-merge-packages.txt`, which `scripts/collect-licenses.sh` writes at build time from the packages actually included: each package's license, copyright line and source, and the MIT License text.
