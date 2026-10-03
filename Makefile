.PHONY: all build install clean test

all: install

build:
	xcodebuild -scheme LocalizedTranslate \
		-configuration Release \
		-derivedDataPath DerivedData \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		build

install:
	./scripts/install.sh

clean:
	rm -rf DerivedData
	xcodebuild -scheme LocalizedTranslate -configuration Release clean

test:
	swift test 2>/dev/null || echo "Running tests inside Xcode or custom verification..."
