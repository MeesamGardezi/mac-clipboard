PRODUCT   = ClipboardManager
APP       = $(PRODUCT).app
BUNDLE    = $(APP)/Contents
MACOS_DIR = $(BUNDLE)/MacOS
RES_DIR   = $(BUNDLE)/Resources
PLIST_SRC = Sources/ClipboardManager/Resources/Info.plist
SIGN_ID   = -   # ad-hoc signing; replace with your Developer ID for distribution

.PHONY: build app run clean

build:
	swift build -c release 2>&1

app: build
	@echo "→ Assembling $(APP)..."
	@mkdir -p "$(MACOS_DIR)" "$(RES_DIR)"
	@cp .build/release/$(PRODUCT) "$(MACOS_DIR)/"
	@cp "$(PLIST_SRC)" "$(BUNDLE)/Info.plist"
	@codesign --force --deep --sign "$(SIGN_ID)" "$(APP)"
	@echo "✓ $(APP) ready"

run: app
	@open "$(APP)"

clean:
	@rm -rf .build "$(APP)"
	@echo "✓ Cleaned"
