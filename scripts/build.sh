#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
OUT="$ROOT/.build/app"
APP="$OUT/Graft.app"
source "$ROOT/scripts/common.sh"
prepare_sources
DOTNET="$(find_dotnet)"

echo "1/3 merge helper"
(cd "$ROOT/Sources/GraftMerge" && "$DOTNET" publish GraftMerge.csproj -c Release -o "$OUT/helper" --nologo -v quiet \
  -r osx-arm64 --self-contained -p:PublishSingleFile=true \
  -p:EnableCompressionInSingleFile=true -p:DebugType=none -p:PublishDocumentationFile=false)

echo "2/3 app"
swift build --package-path "$ROOT" -c release -q
BIN="$(swift build --package-path "$ROOT" -c release --show-bin-path)"

echo "3/3 bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Resources/Templates" "$APP/Contents/Resources/Templates"
cp "$BIN/Graft" "$APP/Contents/MacOS/Graft"
cp "$BIN/graft-cli" "$APP/Contents/Helpers/graft"
cp "$OUT/helper/graft-merge" "$APP/Contents/Helpers/graft-merge"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
LICENSES="$APP/Contents/Resources/Licenses"
mkdir -p "$LICENSES"
cp "$ROOT/vendor/TkSharp/License.md" "$LICENSES/TkSharp-License.md"
cp "$ROOT/vendor/capstone/LICENSE.TXT" "$LICENSES/Capstone-License.txt"
cp "$ROOT/vendor/capstone/LICENSE_LLVM.TXT" "$LICENSES/Capstone-LLVM-License.txt"
cp "$ROOT/Resources/Licenses/AGPL-3.0.txt" "$LICENSES/AGPL-3.0.txt"
NUGET="$(cd "$ROOT/Sources/GraftMerge" && "$DOTNET" nuget locals global-packages --list | sed 's/^global-packages: //')"
"$ROOT/scripts/collect-licenses.sh" "$ROOT/Sources/GraftMerge/obj/Release/net10.0/osx-arm64/graft-merge.deps.json" "$NUGET" "$LICENSES"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP/Contents/Helpers/graft-merge"
codesign --force --sign - "$APP/Contents/Helpers/graft"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "built: $APP"
