APPDIR ?= /Applications
BINDIR ?= $(HOME)/.local/bin
FILTER ?=

APP := .build/app/Graft.app
INSTALLED_APP := $(abspath $(patsubst ~%,$(HOME)%,$(APPDIR)))/Graft.app
INSTALLED_BINDIR := $(abspath $(patsubst ~%,$(HOME)%,$(BINDIR)))
INSTALLED_TOOL := $(INSTALLED_BINDIR)/graft
RUNNING := pgrep -f "^$(INSTALLED_APP)/Contents/MacOS/Graft" > /dev/null

.DEFAULT_GOAL := build
.PHONY: help build test run install uninstall clean dotnet icon

help:
	@echo "make build       build .build/app/Graft.app (the default)"
	@echo "make test        run the C# and Swift tests; FILTER=<name> runs only matching Swift tests"
	@echo "make run         build, then open Graft"
	@echo "make install     build, copy Graft.app to APPDIR and link graft into BINDIR"
	@echo "make uninstall   remove the installed app and the graft link"
	@echo "make clean       delete the build output"
	@echo "make dotnet      install the .NET 10 SDK in ~/.dotnet"
	@echo "make icon        draw the app icon again"
	@echo ""
	@echo "APPDIR=$(APPDIR)  BINDIR=$(BINDIR)"

build:
	./scripts/build.sh

test:
	./scripts/test.sh $(if $(FILTER),--filter '$(FILTER)')

run: build
	open "$(APP)"

install: build
	@if $(RUNNING); then echo "Quit Graft before installing over $(INSTALLED_APP)." >&2; exit 1; fi
	rm -rf "$(INSTALLED_APP)"
	ditto "$(APP)" "$(INSTALLED_APP)"
	mkdir -p "$(INSTALLED_BINDIR)"
	ln -sfn "$(INSTALLED_APP)/Contents/Helpers/graft" "$(INSTALLED_TOOL)"
	@echo "Installed $(INSTALLED_APP) and linked $(INSTALLED_TOOL)."

uninstall:
	@if $(RUNNING); then echo "Quit Graft before removing $(INSTALLED_APP)." >&2; exit 1; fi
	rm -rf "$(INSTALLED_APP)"
	@if [ -L "$(INSTALLED_TOOL)" ] && [ "$$(readlink "$(INSTALLED_TOOL)")" = "$(INSTALLED_APP)/Contents/Helpers/graft" ]; then rm "$(INSTALLED_TOOL)"; echo "rm $(INSTALLED_TOOL)"; fi

clean:
	rm -rf .build Sources/GraftMerge/bin Sources/GraftMerge/obj Tests/GraftMergeTests/bin Tests/GraftMergeTests/obj

dotnet:
	./scripts/install-dotnet.sh

icon:
	./scripts/make-icon.sh
