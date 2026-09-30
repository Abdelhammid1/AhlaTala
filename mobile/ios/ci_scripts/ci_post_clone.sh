#!/bin/sh
# Xcode Cloud post-clone hook — runs after the repo is cloned but
# BEFORE any Xcode build step. Bootstraps Flutter + CocoaPods so the
# native plugin pods (MapLibre, geolocator_apple, shared_preferences_
# foundation, etc.) resolve and get linked into the Runner target.
#
# Docs: https://docs.flutter.dev/deployment/cd#xcode-cloud

# `set -e` bails on any failure. `set -x` echoes every command with
# its expansion so the Xcode Cloud log tells us exactly which line
# broke, not just an anonymous 'exited with code 1'.
set -ex

STEP() { echo ""; echo "───── STEP: $1 ─────"; }

STEP "environment"
echo "PWD:          $(pwd)"
echo "HOME:         $HOME"
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "PATH:         $PATH"
echo "ruby:         $(ruby --version 2>&1 || echo 'not installed')"
echo "pod:          $(pod --version 2>&1 || echo 'not installed')"
echo "xcodebuild:   $(xcodebuild -version 2>&1 | head -1 || echo 'not installed')"

REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"

STEP "1) install Flutter stable"
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
else
  echo "Flutter already cached at $FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"
flutter --version
flutter precache --ios --no-android

STEP "2) flutter pub get"
cd "$REPO_ROOT"
flutter pub get

STEP "3) install CocoaPods if missing"
# Xcode Cloud runners come with Ruby but not always CocoaPods; sudo is
# passwordless on the runner user. Fall back to a userspace install if
# sudo fails for any reason.
if ! command -v pod > /dev/null; then
  sudo gem install cocoapods || gem install --user-install cocoapods
  export PATH="$(ruby -e 'puts Gem.user_dir')/bin:$PATH"
fi
pod --version

STEP "4) force iOS deployment target in auto-generated Podfile"
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

STEP "5) flutter build ios --config-only (generates registrant + runs pod install)"
cd "$REPO_ROOT"
flutter build ios --release --no-codesign --config-only

STEP "6) verify Pods directory + workspace linkage"
if [ ! -d "$REPO_ROOT/ios/Pods" ]; then
  echo "!! ios/Pods missing after flutter build — falling back to manual pod install."
  cd "$REPO_ROOT/ios"
  pod install --repo-update --verbose
fi
echo "--- Workspace content after setup ---"
cat "$REPO_ROOT/ios/Runner.xcworkspace/contents.xcworkspacedata"
echo "--- Podfile.lock (top 30 lines) ---"
head -30 "$REPO_ROOT/ios/Podfile.lock" 2>&1 || echo "(no Podfile.lock)"

STEP "done"
echo "=== ci_post_clone complete ==="
