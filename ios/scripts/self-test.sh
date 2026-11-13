#!/bin/zsh
# Runs the iPhone app's launch-argument self test in the simulator and always shuts the simulator down.
#
#   1. Build the app, one build at a time, through the guard:
#        cd ios && xcodegen generate && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
#          && ~/.claude/heavy.sh xcodebuild -project SpeakAway.xcodeproj -scheme SpeakAway \
#             -destination 'platform=iOS Simulator,id=0AA0BE12-6FBE-47E4-9542-A6D192982BFD' \
#             -derivedDataPath .build/dd CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
#   2. Run this script through the guard:
#        ~/.claude/heavy.sh ios/scripts/self-test.sh
#
# Booting the simulator can add several GB of swap on a Mac with little free memory, and swap lives on the same
# disk. The very first boot of a runtime also writes its shared cache (about 3 GB, kept afterwards under
# /Library/Developer/CoreSimulator/Caches). The script refuses to start with less than 4 GB free (set
# SPEAKAWAY_MIN_START_GB, use 7 when that cache is missing) and stops everything if free space falls under
# 2.5 GB while it runs. It creates its test audio with `say` in ios/.build/selftest and removes that folder at the end.

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
DEVICE=${SPEAKAWAY_SIM_DEVICE:-0AA0BE12-6FBE-47E4-9542-A6D192982BFD}
BUNDLE=com.opensourceeverything.speakaway
GROUP=group.com.opensourceeverything.speakaway
IOS=${0:A:h:h}
APP=$IOS/.build/dd/Build/Products/Debug-iphonesimulator/SpeakAway.app
WORK=$IOS/.build/selftest
MIN_START_GB=${SPEAKAWAY_MIN_START_GB:-4}
MIN_RUN_GB=2.5
failures=0

free_gb() { df -k /System/Volumes/Data | awk 'NR==2{printf "%.1f", $4/1048576}'; }

cleanup() {
  xcrun simctl terminate $DEVICE $BUNDLE >/dev/null 2>&1
  xcrun simctl shutdown all >/dev/null 2>&1
  [[ $WORK == */ios/.build/selftest ]] && rm -rf $WORK
  echo "cleanup: simulator shut down, test folder removed"
}
trap cleanup EXIT
trap 'exit 143' INT TERM HUP

# guarded <seconds> <command...>: runs the command while watching the clock and the free space.
guarded() {
  local limit=$1; shift
  "$@" &
  local pid=$! waited=0
  while kill -0 $pid 2>/dev/null; do
    if (( $(free_gb) < MIN_RUN_GB )); then
      echo "STOP: only $(free_gb) GB free, stopping to protect the Mac"
      kill $pid 2>/dev/null
      exit 75
    fi
    if (( waited >= limit )); then
      echo "TIMEOUT after ${limit}s"
      xcrun simctl terminate $DEVICE $BUNDLE >/dev/null 2>&1
      kill $pid 2>/dev/null
      break
    fi
    sleep 2
    waited=$((waited + 2))
  done
  wait $pid 2>/dev/null
}

# run_test <name> <seconds> <arguments...>
run_test() {
  local name=$1 limit=$2; shift 2
  echo "=== $name"
  guarded $limit xcrun simctl launch --console-pty $DEVICE $BUNDLE --self-test "$@" > $WORK/$name.log 2>&1
  tail -n 45 $WORK/$name.log
  grep -q "SELF TEST RESULT: PASS" $WORK/$name.log || failures=$((failures + 1))
}

[[ -d $APP ]] || { echo "build the app first (see the top of this file): $APP"; exit 2; }
(( $(free_gb) >= MIN_START_GB )) || { echo "only $(free_gb) GB free, need $MIN_START_GB GB before booting the simulator"; exit 75; }

mkdir -p $WORK
say -v Samantha --file-format=WAVE --data-format=LEI16@16000 -o $WORK/en.wav "Hello team, um, let's meet tomorrow at three in the afternoon. Please send me the report." || exit 3
say -v Paulina --file-format=WAVE --data-format=LEI16@16000 -o $WORK/es.wav "Hola equipo, eh, nos vemos mañana a las tres de la tarde. Por favor mándame el informe." || exit 3
say -v Samantha -o $WORK/command.aiff "Make it more formal." || exit 3

echo "boot"
xcrun simctl boot $DEVICE 2>&1 | tail -1
guarded 300 xcrun simctl bootstatus $DEVICE -b
echo "install"
guarded 120 xcrun simctl install $DEVICE $APP
xcrun simctl privacy $DEVICE grant microphone $BUNDLE
DATA=$(xcrun simctl get_app_container $DEVICE $BUNDLE data)
mkdir -p $DATA/tmp/selftest
cp $WORK/en.wav $WORK/es.wav $WORK/command.aiff $DATA/tmp/selftest/
T=$DATA/tmp/selftest

run_test ab 120
echo "--- group container seen from the Mac side"
G=$(xcrun simctl get_app_container $DEVICE $BUNDLE $GROUP 2>&1)
echo "$G"
ls -la "$G" 2>&1 | head -12

run_test c-en 420 --transcribe-file $T/en.wav --locale en-US
run_test c-es 420 --transcribe-file $T/es.wav --locale es-MX
run_test d-session 600 --session-file $T/en.wav --command-file $T/command.aiff --locale en-US

echo "runs that did not end in PASS: $failures"
exit $(( failures > 0 ))
