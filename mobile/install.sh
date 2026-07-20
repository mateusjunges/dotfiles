#!/bin/sh
#
# Mobile development
#
# Installs the iOS toolchain pieces that Homebrew cannot provide.
# Android Studio, the JDK and CocoaPods come from the Brewfile.

if test "$(uname)" != "Darwin"
then
  exit 0
fi

# Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1
then
  echo "  Installing Xcode Command Line Tools..."
  xcode-select --install
fi

# Full Xcode is required to build and run iOS apps (simulators, SDKs).
# It is only distributed through the Mac App Store, so we use mas.
if ! test -d /Applications/Xcode.app
then
  if test $(which mas)
  then
    echo "  Installing Xcode from the Mac App Store (this is a large download)..."
    mas install 497799835 || echo "  Could not install Xcode automatically. Sign in to the App Store and run: mas install 497799835"
  else
    echo "  Xcode not found. Install it from the Mac App Store to build iOS apps."
  fi
fi

# First-launch setup: accept the license and install the iOS platform/simulator
if test -d /Applications/Xcode.app
then
  if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1
  then
    echo "  Running Xcode first-launch setup (may ask for your password)..."
    sudo xcodebuild -license accept
    sudo xcodebuild -runFirstLaunch
    xcodebuild -downloadPlatform iOS
  fi
fi

exit 0
