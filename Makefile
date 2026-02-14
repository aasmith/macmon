APP_NAME = macmon
BUNDLE = $(APP_NAME).app

all: clean build bundle

build:
	clang -fobjc-arc -O2 -Wall -Wextra \
		-framework Cocoa \
		main.m -o $(APP_NAME)

bundle:
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	rm $(APP_NAME)

clean:
	rm -rf $(BUNDLE) $(APP_NAME)

run: all
	open $(BUNDLE)

.PHONY: all build bundle clean run
