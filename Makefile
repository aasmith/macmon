APP_NAME = macmon
BUNDLE = $(APP_NAME).app
DMG = $(APP_NAME).dmg
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)

all: clean build icon bundle sign

build:
	clang -fobjc-arc -O2 -Wall -Wextra \
		-DGIT_SHA=\"$(GIT_SHA)\" \
		-framework Cocoa \
		main.m -o $(APP_NAME)

icon:
	clang -fobjc-arc -O2 -framework Cocoa gen_icon.m -o gen_icon
	./gen_icon
	iconutil -c icns macmon.iconset
	rm -rf gen_icon macmon.iconset

bundle:
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(APP_NAME) $(BUNDLE)/Contents/MacOS/
	sed 's/GIT_SHA/$(GIT_SHA)/' Info.plist > $(BUNDLE)/Contents/Info.plist
	cp macmon.icns $(BUNDLE)/Contents/Resources/
	rm $(APP_NAME) macmon.icns

sign:
	codesign --force --deep -s - $(BUNDLE)

dist: all
	rm -rf dmg_staging $(DMG)
	mkdir dmg_staging
	cp -r $(BUNDLE) dmg_staging/
	ln -s /Applications dmg_staging/Applications
	hdiutil create -volname "macmon $(GIT_SHA)" \
		-srcfolder dmg_staging -ov -format UDZO $(DMG)
	rm -rf dmg_staging

clean:
	rm -rf $(BUNDLE) $(APP_NAME) $(DMG) dmg_staging \
		gen_icon macmon.iconset macmon.icns

run: all
	open $(BUNDLE)

.PHONY: all build icon bundle sign dist clean run
