#!/bin/bash
# Builds Pocketknife in Release and wraps it in an installer package that puts
# the app straight into /Applications.
#
#   Scripts/make-installer.sh        -> build/Pocketknife-<version>.pkg
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="CliDB.xcodeproj"
SCHEME="CliDB"
APP_NAME="Pocketknife"
PKG_ID="com.miy33t.CliDB.pkg"

OUT="build"
DERIVED="$OUT/DerivedData"
WORK="$OUT/installer"

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION / { print $2; exit }')
[ -n "$VERSION" ] || { echo "Couldn't read MARKETING_VERSION" >&2; exit 1; }

echo "==> Building $APP_NAME $VERSION (Release)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$DERIVED" build -quiet

APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "Build product not found: $APP" >&2; exit 1; }

rm -rf "$WORK"
mkdir -p "$WORK/root"
ditto "$APP" "$WORK/root/$APP_NAME.app"

# By default the installer "relocates" a bundle: if it finds another copy of the
# app anywhere on disk (Downloads, a build folder…) it updates that copy instead
# of installing to /Applications. Turn that off so the app always lands there.
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$WORK/component.plist"

echo "==> Packaging"
pkgbuild --root "$WORK/root" \
    --component-plist "$WORK/component.plist" \
    --install-location /Applications \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    "$WORK/$APP_NAME-component.pkg" >/dev/null

PKG="$OUT/$APP_NAME-$VERSION.pkg"
productbuild --package "$WORK/$APP_NAME-component.pkg" "$PKG" >/dev/null

echo "==> $PKG"
