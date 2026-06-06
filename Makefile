.PHONY: build run app companion-package install-svg install-image clean

EXECUTABLE_NAME := DesktopCompanion
APP_NAME ?= DesktopCompanion
BUNDLE_ID ?= com.ptapayan.DesktopCompanion
SUPPORT_DIR_NAME ?= $(APP_NAME)
COMPANION_PACKAGE ?=
COMPANION_PACKAGE_SOURCE = $(if $(COMPANION_PACKAGE),$(COMPANION_PACKAGE),Sources/DesktopCompanion/Resources/Companions/default)
OUT ?= .build/companions/$(ID)
APP_DIR := .build/app/$(APP_NAME).app
APP_CONTENTS := $(APP_DIR)/Contents
RESOURCE_BUNDLE := .build/release/$(EXECUTABLE_NAME)_$(EXECUTABLE_NAME).bundle
SIGNING_REQUIREMENT := =designated => identifier "$(BUNDLE_ID)"

build:
	swift build

run:
	swift run $(EXECUTABLE_NAME)

app:
	swift build -c release
	@test -f "$(COMPANION_PACKAGE_SOURCE)/companion.json" || (echo "COMPANION_PACKAGE must contain companion.json" >&2; exit 65)
	rm -rf "$(RESOURCE_BUNDLE)/Companions/default"
	mkdir -p "$(RESOURCE_BUNDLE)/Companions"
	cp -R "$(COMPANION_PACKAGE_SOURCE)" "$(RESOURCE_BUNDLE)/Companions/default"
	mkdir -p "$(APP_CONTENTS)/MacOS" "$(APP_CONTENTS)/Resources"
	cp ".build/release/$(EXECUTABLE_NAME)" "$(APP_CONTENTS)/MacOS/$(APP_NAME)"
	cp "packaging/Info.plist" "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME)" "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME)" "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID)" "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :DesktopCompanionSupportDirectory $(SUPPORT_DIR_NAME)" "$(APP_CONTENTS)/Info.plist"
	cp -R "$(RESOURCE_BUNDLE)" "$(APP_CONTENTS)/Resources/"
	codesign --force --deep --sign - --requirements '$(SIGNING_REQUIREMENT)' "$(APP_DIR)"
	@echo "Built $(APP_DIR)"

companion-package:
	@test -n "$(SVG)" || (echo "usage: make companion-package SVG=/path/to/companion.svg ID=companion-id NAME='Companion Name' [OUT=.build/companions/companion-id]" >&2; exit 64)
	@test -n "$(ID)" || (echo "usage: make companion-package SVG=/path/to/companion.svg ID=companion-id NAME='Companion Name' [OUT=.build/companions/companion-id]" >&2; exit 64)
	@test -n "$(NAME)" || (echo "usage: make companion-package SVG=/path/to/companion.svg ID=companion-id NAME='Companion Name' [OUT=.build/companions/companion-id]" >&2; exit 64)
	scripts/create-companion-package.sh "$(SVG)" "$(OUT)" "$(ID)" "$(NAME)" "$(THEMES)"

install-svg:
	@test -n "$(SVG)" || (echo "usage: make install-svg SVG=/path/to/companion.svg" >&2; exit 64)
	DESKTOP_COMPANION_SUPPORT_DIR_NAME="$(SUPPORT_DIR_NAME)" scripts/install-svg.sh "$(SVG)"

install-image:
	@test -n "$(IMAGE)" || (echo "usage: make install-image IMAGE=/path/to/image.png" >&2; exit 64)
	DESKTOP_COMPANION_SUPPORT_DIR_NAME="$(SUPPORT_DIR_NAME)" scripts/install-image.sh "$(IMAGE)"

clean:
	rm -rf .build
