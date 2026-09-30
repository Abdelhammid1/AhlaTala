#!/bin/sh
# Xcode Cloud post-clone hook — runs after the repo is cloned but
# BEFORE any Xcode build step. Bootstraps Flutter + CocoaPods so the
# native plugin pods (MapLibre, geolocator_apple, shared_preferences_
# foundation, etc.) resolve and get linked into the Runner target.
#
# Without this, Xcode Cloud clones the repo, sees no Podfile, and
# jumps straight to `xcodebuild build` — which fails with exit-code
# 65 the moment GeneratedPluginRegistrant.m references classes from
# pods that were never installed.
#
# Docs: https://docs.flutter.dev/deployment/cd#xcode-cloud
set -e

echo "=== Xcode Cloud post-clone: bootstrap Flutter + CocoaPods ==="

REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
echo "Repo root: $REPO_ROOT"

# ---- 1) Install Flutter (stable, cached to speed subsequent runs) ----
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  echo "Cloning Flutter stable..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

flutter --version
flutter precache --ios --no-android

# ---- 2) Resolve Dart packages ----
cd "$REPO_ROOT"
echo "Running flutter pub get..."
flutter pub get

# ---- 3) Ensure CocoaPods is installed on the runner ----
if ! command -v pod > /dev/null; then
  echo "Installing CocoaPods..."
  sudo gem install cocoapods
fi

# ---- 4) Force iOS deployment target in the auto-generated Podfile ----
# Flutter's default Podfile ships with `platform :ios` commented out.
# Recent Flutter (3.47+) requires iOS 15+ for the Flutter framework pod;
# without an explicit platform line, pod install can still resolve the
# wrong version. Force it BEFORE flutter build runs pod install.
cd "$REPO_ROOT/ios"
if [ -f Podfile ]; then
  if grep -qE "^# platform :ios" Podfile; then
    sed -i.bak "s/^# platform :ios.*/platform :ios, '15.0'/" Podfile
  elif grep -qE "^platform :ios" Podfile; then
    sed -i.bak "s/^platform :ios.*/platform :ios, '15.0'/" Podfile
  else
    printf "platform :ios, '15.0'\n%s\n" "$(cat Podfile)" > Podfile.new && mv Podfile.new Podfile
  fi
  rm -f Podfile.bak
  echo "--- Podfile head ---"
  head -5 Podfile
  echo "--------------------"
fi

# ---- 5) Prepare the iOS project via Flutter (this does the heavy lifting) ----
# `flutter build ios --config-only` (a) generates the plugin registrant,
# (b) writes Generated.xcconfig, and (c) runs `pod install` with the
# correct plugin list — the same sequence Flutter uses when you build
# from your laptop. Doing it explicitly here means Xcode Cloud's xcodebuild
# step finds a fully-configured Runner.xcworkspace with the Pods project
# already linked in.
cd "$REPO_ROOT"
echo "Running flutter build ios --config-only..."
flutter build ios --release --no-codesign --config-only

# ---- 6) Verify Pods installed ----
if [ ! -d "$REPO_ROOT/ios/Pods" ]; then
  echo "!! ios/Pods directory missing after flutter build — pod install must have failed."
  cd "$REPO_ROOT/ios"
  pod install --repo-update --verbose
fi

echo "--- Workspace content after setup ---"
cat "$REPO_ROOT/ios/Runner.xcworkspace/contents.xcworkspacedata"
echo "-------------------------------------"

echo "=== ci_post_clone complete ==="
