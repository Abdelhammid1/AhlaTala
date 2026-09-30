#!/bin/sh
# Xcode Cloud post-clone hook — runs after the repo is cloned but
# BEFORE any Xcode build step. Bootstraps Flutter + CocoaPods so the
# native MapLibre pod (and every other Flutter plugin) resolves.
#
# Without this, Xcode Cloud clones the repo, sees no Podfile, and
# jumps straight to `xcodebuild build` — which fails with exit-code
# 65 the moment the plugin registrant references classes from pods
# that were never installed.
#
# The script:
#   1. Installs Flutter (stable channel) into $CI_PRIMARY_REPOSITORY_PATH/flutter
#   2. Adds it to PATH for subsequent build steps
#   3. Runs `flutter pub get` to generate Podfile + fetch deps
#   4. Runs `pod install` in the ios/ folder
#
# Docs: https://docs.flutter.dev/deployment/cd#xcode-cloud
set -e

echo "=== Xcode Cloud post-clone: bootstrap Flutter + CocoaPods ==="

# Xcode Cloud clones the repo into $CI_PRIMARY_REPOSITORY_PATH.
# When Ibrahim's remote (the mobile-only subtree) is the target, this
# script lives at ios/ci_scripts/ci_post_clone.sh and the workspace
# root is $CI_PRIMARY_REPOSITORY_PATH.
REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
echo "Repo root: $REPO_ROOT"

# ---- 1) Install Flutter (stable, cached to speed subsequent runs) ----
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  echo "Cloning Flutter stable..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

# Warm up Flutter (accepts licenses, downloads Dart SDK, iOS artifacts).
flutter --version
flutter precache --ios

# ---- 2) Resolve Dart packages (generates ios/Flutter/Generated.xcconfig) ----
cd "$REPO_ROOT"
echo "Running flutter pub get..."
flutter pub get

# ---- 3) Force iOS deployment target in the auto-generated Podfile ----
# Flutter's default Podfile ships with `platform :ios, '13.0'` commented
# out. Recent Flutter (3.47+) requires iOS 15+ for the Flutter framework
# pod; without an explicit platform line, pod install analyses deps
# against Xcode's project setting and can still resolve wrong. Force it.
cd "$REPO_ROOT/ios"
if [ -f Podfile ]; then
  # If the platform line is commented out (default), uncomment + set 15.0.
  # If it's set to anything else, replace with 15.0.
  if grep -qE "^# platform :ios" Podfile; then
    sed -i.bak "s/^# platform :ios.*/platform :ios, '15.0'/" Podfile
  elif grep -qE "^platform :ios" Podfile; then
    sed -i.bak "s/^platform :ios.*/platform :ios, '15.0'/" Podfile
  else
    # No platform line at all — prepend one.
    printf "platform :ios, '15.0'\n%s\n" "$(cat Podfile)" > Podfile.new && mv Podfile.new Podfile
  fi
  rm -f Podfile.bak
  echo "--- Podfile head ---"
  head -5 Podfile
  echo "--------------------"
fi

# ---- 4) Install CocoaPods (Xcode Cloud has ruby but not always pods) ----
if ! command -v pod > /dev/null; then
  echo "Installing CocoaPods..."
  sudo gem install cocoapods
fi
echo "Running pod install..."
pod install --repo-update

echo "=== ci_post_clone complete ==="
