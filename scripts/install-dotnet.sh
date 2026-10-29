#!/bin/zsh
set -euo pipefail

installer="$(mktemp /tmp/dotnet-install.XXXXXX)"
trap 'rm -f "$installer"' EXIT
curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
bash "$installer" --channel 10.0 --install-dir "$HOME/.dotnet"
print "Installed the .NET 10 SDK in ~/.dotnet. scripts/build.sh and scripts/test.sh use it from there."
