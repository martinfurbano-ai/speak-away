#!/bin/zsh
# Builds Speak Away.app into app/dist, then either a .dmg (default) or a Mac App Store .pkg (TARGET=appstore).
#
#   ./scripts/build-app.sh                                   ad-hoc signed .dmg (anyone can build this)
#   SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=<profile> ./scripts/build-app.sh
#                                                            signed and notarized .dmg
#   TARGET=appstore SIGN_IDENTITY="Apple Distribution: …" INSTALLER_IDENTITY="3rd Party Mac Developer Installer: …" \
#     PROFILE=path/to.provisionprofile BUILD=2 ./scripts/build-app.sh
#                                                            sandboxed .pkg for App Store Connect
set -euo pipefail

APP_DIR=${0:A:h:h}
VERSION=${VERSION:-0.1.1}
BUILD=${BUILD:-1}
TARGET=${TARGET:-dmg}
DIST=$APP_DIR/dist
BUNDLE="$DIST/Speak Away.app"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

cd $APP_DIR
swift build -c release --arch arm64
BIN=$APP_DIR/.build/arm64-apple-macosx/release

rm -rf $DIST && mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp $BIN/SpeakAway "$BUNDLE/Contents/MacOS/SpeakAway"
cp $APP_DIR/Resources/PrivacyInfo.xcprivacy "$BUNDLE/Contents/Resources/"

# Icon: the Icon Composer file compiles to Assets.car (Liquid Glass on macOS 26) plus a full .icns for older macOS.
WORK=$(mktemp -d)
xcrun actool --compile "$BUNDLE/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 \
  --app-icon SpeakAway --output-partial-info-plist $WORK/icon.plist $APP_DIR/Resources/SpeakAway.icon >/dev/null
ICTOOL="$DEVELOPER_DIR/../Applications/Icon Composer.app/Contents/Executables/ictool"
ICONSET=$WORK/SpeakAway.iconset
mkdir -p $ICONSET
"$ICTOOL" $APP_DIR/Resources/SpeakAway.icon --export-image --output-file $WORK/icon_1024.png \
  --platform macOS --rendition Default --width 1024 --height 1024 --scale 1 >/dev/null
for s in 16 32 128 256 512; do
  sips -z $s $s $WORK/icon_1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) $WORK/icon_1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$BUNDLE/Contents/Resources/SpeakAway.icns"

sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" $APP_DIR/Resources/Info.plist > "$BUNDLE/Contents/Info.plist"

if [[ $TARGET == appstore ]]; then
  : ${SIGN_IDENTITY:?Apple Distribution identity} ${INSTALLER_IDENTITY:?installer identity} ${PROFILE:?provisioning profile}
  cp $PROFILE "$BUNDLE/Contents/embedded.provisionprofile"
  TEAM=$(security cms -D -i $PROFILE | plutil -extract TeamIdentifier.0 raw -o - -)
  sed "s/__TEAM__/$TEAM/g" $APP_DIR/Resources/SpeakAway-AppStore.entitlements > $WORK/appstore.entitlements
  codesign --force --sign "$SIGN_IDENTITY" --entitlements $WORK/appstore.entitlements "$BUNDLE"
  codesign --verify --strict "$BUNDLE"
  productbuild --component "$BUNDLE" /Applications --sign "$INSTALLER_IDENTITY" $DIST/SpeakAway.pkg >/dev/null
  echo "Listo: $DIST/SpeakAway.pkg ($(du -h $DIST/SpeakAway.pkg | cut -f1)), versión $VERSION ($BUILD)"
  exit 0
fi

if [[ -n ${SIGN_IDENTITY:-} ]]; then
  codesign --force --options runtime --timestamp \
    --entitlements $APP_DIR/Resources/SpeakAway.entitlements --sign "$SIGN_IDENTITY" "$BUNDLE"
else
  codesign --force --sign - "$BUNDLE"
fi
codesign --verify --strict "$BUNDLE"

STAGE=$(mktemp -d)
cp -R "$BUNDLE" $STAGE/
ln -s /Applications $STAGE/Applications
hdiutil create -volname "Speak Away" -srcfolder $STAGE -ov -format UDZO $DIST/SpeakAway.dmg >/dev/null

if [[ -n ${NOTARY_PROFILE:-} ]]; then
  xcrun notarytool submit $DIST/SpeakAway.dmg --keychain-profile $NOTARY_PROFILE --wait
  xcrun stapler staple $DIST/SpeakAway.dmg
fi

echo "Listo: $DIST/SpeakAway.dmg ($(du -h $DIST/SpeakAway.dmg | cut -f1)), versión $VERSION ($BUILD)"
