APP_NAME = macmon
BUNDLE = $(APP_NAME).app
DMG = $(APP_NAME).dmg
VERSION = 1.0

all: clean build bundle sign

build:
	clang -fobjc-arc -O2 -Wall -Wextra \
		-framework Cocoa \
		main.m -o $(APP_NAME)

bundle:
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	rm $(APP_NAME)

sign:
	codesign --force --deep -s - $(BUNDLE)

dist: all
	rm -rf dmg_staging $(DMG)
	mkdir dmg_staging
	cp -r $(BUNDLE) dmg_staging/
	ln -s /Applications dmg_staging/Applications
	hdiutil create -volname "macmon $(VERSION)" \
		-srcfolder dmg_staging -ov -format UDZO $(DMG)
	rm -rf dmg_staging

clean:
	rm -rf $(BUNDLE) $(APP_NAME) $(DMG) dmg_staging

run: all
	open $(BUNDLE)

.PHONY: all build bundle sign dist clean run
