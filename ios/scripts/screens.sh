#!/bin/zsh
# Takes the screenshots of the iPhone app: every screen, in light and dark, in Spanish and English, with the
# fictional sample data of the app's `--preview <screen>` mode (nothing real is read, nothing is written).
#
#   ios/scripts/screens.sh <udid> <outdir> [screen ...]
#
# Without screens it takes all of them: home history notes meetings meeting-detail voice dictionary snippets style
# settings onboarding-1 ... onboarding-5 session keyboard keyboard-recording keyboard-result.
# The files are named <screen>-<lang>-<appearance>.png, for example home-es-dark.png.
#
# The simulator has to be booted already: this script never boots one (it can add several GB of swap on a Mac with
# little free memory, and swap lives on the same disk). It refuses to start with less than 3 GB free and stops if the
# space falls under that while it runs. When it ends it clears the status bar and quits the app; the simulator stays
# booted, because it was not started here.
#
# Build the app first, one build at a time, through the guard:
#   cd ios && xcodegen generate && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
#     && ~/.claude/heavy.sh xcodebuild -project SpeakAway.xcodeproj -scheme SpeakAway \
#        -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/dd \
#        CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
# Then, with a booted simulator:
#   ~/.claude/heavy.sh ios/scripts/screens.sh <udid> ~/Desktop/speakaway-screens
#
# SPEAKAWAY_SETTLE sets the seconds to wait for a screen to finish drawing (default 3).
# SPEAKAWAY_APP sets a different .app to install.

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
BUNDLE=com.opensourceeverything.speakaway
IOS=${0:A:h:h}
APP=${SPEAKAWAY_APP:-$IOS/.build/dd/Build/Products/Debug-iphonesimulator/SpeakAway.app}
SETTLE=${SPEAKAWAY_SETTLE:-3}
MIN_FREE_GB=3
ALL_SCREENS=(home history notes meetings meeting-detail voice dictionary snippets style settings
             onboarding-1 onboarding-2 onboarding-3 onboarding-4 onboarding-5
             session keyboard keyboard-recording keyboard-result)
LOOKS=(light dark)
LANGS=(es en)

free_gb() { df -k /System/Volumes/Data | awk 'NR==2{printf "%.1f", $4/1048576}'; }

usage() {
  print -u2 "usage: ios/scripts/screens.sh <udid> <outdir> [screen ...]"
  print -u2 "screens: $ALL_SCREENS"
}

UDID=$1
OUT=$2
if [[ -z $UDID || -z $OUT ]]; then
  usage
  exit 2
fi
shift 2
SCREENS=("$@")
(( ${#SCREENS} )) || SCREENS=($ALL_SCREENS)

for screen in $SCREENS; do
  if (( ! ${ALL_SCREENS[(Ie)$screen]} )); then
    print -u2 "unknown screen: $screen"
    usage
    exit 2
  fi
done

if ! xcrun simctl list devices booted | grep -q "$UDID"; then
  print -u2 "the simulator $UDID is not booted; boot it first (this script never does)"
  exit 2
fi
[[ -d $APP ]] || { print -u2 "build the app first (see the top of this file): $APP"; exit 2; }
(( $(free_gb) >= MIN_FREE_GB )) || { print -u2 "only $(free_gb) GB free, need $MIN_FREE_GB GB"; exit 75; }

cleanup() {
  xcrun simctl terminate $UDID $BUNDLE >/dev/null 2>&1
  xcrun simctl status_bar $UDID clear >/dev/null 2>&1
  print "cleanup: app closed, status bar restored (the simulator was left booted)"
}
trap cleanup EXIT
trap 'exit 143' INT TERM HUP

mkdir -p "$OUT" || exit 3
xcrun simctl install $UDID "$APP" || exit 3
xcrun simctl status_bar $UDID override --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName '' --dataNetwork wifi

shots=0
failures=0
for screen in $SCREENS; do
  for look in $LOOKS; do
    for lang in $LANGS; do
      if (( $(free_gb) < MIN_FREE_GB )); then
        print -u2 "STOP: only $(free_gb) GB free, stopping to protect the Mac"
        exit 75
      fi
      locale=en_US
      [[ $lang == es ]] && locale=es_PA
      file="$OUT/$screen-$lang-$look.png"
      xcrun simctl terminate $UDID $BUNDLE >/dev/null 2>&1
      if xcrun simctl launch $UDID $BUNDLE --preview $screen --appearance $look \
           -AppleLanguages "($lang)" -AppleLocale $locale >/dev/null 2>&1; then
        sleep $SETTLE
        if xcrun simctl io $UDID screenshot --type=png "$file" >/dev/null 2>&1; then
          shots=$((shots + 1))
          print "ok    $file"
        else
          failures=$((failures + 1))
          print -u2 "FAIL  screenshot of $screen ($lang, $look)"
        fi
      else
        failures=$((failures + 1))
        print -u2 "FAIL  launch of $screen ($lang, $look)"
      fi
    done
  done
done

print "$shots screenshots in $OUT, $failures failures"
(( failures == 0 ))
