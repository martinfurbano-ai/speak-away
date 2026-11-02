#!/bin/zsh
# Builds Speak Away.app and SpeakAway.dmg into app/dist.
# Signs with SIGN_IDENTITY when set (a "Developer ID Application" certificate), ad-hoc otherwise.
# Notarizes when NOTARY_PROFILE is set (xcrun notarytool store-credentials <profile>).
set -euo pipefail

APP_DIR=${0:A:h:h}
VERSION=${VERSION:-0.1.0}
DIST=$APP_DIR/dist
BUNDLE="$DIST/Speak Away.app"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

cd $APP_DIR
swift build -c release --arch arm64
BIN=$APP_DIR/.build/arm64-apple-macosx/release

rm -rf $DIST && mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp $BIN/SpeakAway "$BUNDLE/Contents/MacOS/SpeakAway"
for b in $BIN/*.bundle(N); do cp -R $b "$BUNDLE/Contents/Resources/"; done

# Icon
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p $ICONSET
swift $APP_DIR/scripts/make-icon.swift $ICONSET/icon_1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s $ICONSET/icon_1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) $ICONSET/icon_1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
rm $ICONSET/icon_1024.png
iconutil -c icns $ICONSET -o "$BUNDLE/Contents/Resources/AppIcon.icns"

sed "s/__VERSION__/$VERSION/g" $APP_DIR/Resources/Info.plist > "$BUNDLE/Contents/Info.plist"

if [[ -n ${SIGN_IDENTITY:-} ]]; then
  codesign --force --deep --options runtime --timestamp \
    --entitlements $APP_DIR/Resources/SpeakAway.entitlements --sign "$SIGN_IDENTITY" "$BUNDLE"
else
  codesign --force --deep --sign - "$BUNDLE"
fi
codesign --verify --deep --strict "$BUNDLE"

STAGE=$(mktemp -d)
cp -R "$BUNDLE" $STAGE/
ln -s /Applications $STAGE/Applications
hdiutil create -volname "Speak Away" -srcfolder $STAGE -ov -format UDZO $DIST/SpeakAway.dmg >/dev/null

if [[ -n ${NOTARY_PROFILE:-} ]]; then
  xcrun notarytool submit $DIST/SpeakAway.dmg --keychain-profile $NOTARY_PROFILE --wait
  xcrun stapler staple $DIST/SpeakAway.dmg
fi

echo "Listo: $DIST/SpeakAway.dmg ($(du -h $DIST/SpeakAway.dmg | cut -f1))"
