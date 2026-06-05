.PHONY: build run app install-svg install-image clean

APP_NAME := DesktopCompanion
APP_DIR := .build/app/$(APP_NAME).app
APP_CONTENTS := $(APP_DIR)/Contents
RESOURCE_BUNDLE := .build/release/$(APP_NAME)_$(APP_NAME).bundle
SIGNING_REQUIREMENT := =designated => identifier "com.ptapayan.DesktopCompanion"

build:
	swift build

run:
	swift run $(APP_NAME)

app:
	swift build -c release
	mkdir -p "$(APP_CONTENTS)/MacOS" "$(APP_CONTENTS)/Resources"
	cp ".build/release/$(APP_NAME)" "$(APP_CONTENTS)/MacOS/$(APP_NAME)"
	cp "packaging/Info.plist" "$(APP_CONTENTS)/Info.plist"
	cp -R "$(RESOURCE_BUNDLE)" "$(APP_CONTENTS)/Resources/"
	codesign --force --deep --sign - --requirements '$(SIGNING_REQUIREMENT)' "$(APP_DIR)"
	@echo "Built $(APP_DIR)"

install-svg:
	@test -n "$(SVG)" || (echo "usage: make install-svg SVG=/path/to/companion.svg" >&2; exit 64)
	scripts/install-svg.sh "$(SVG)"

install-image:
	@test -n "$(IMAGE)" || (echo "usage: make install-image IMAGE=/path/to/image.png" >&2; exit 64)
	scripts/install-image.sh "$(IMAGE)"

clean:
	rm -rf .build
