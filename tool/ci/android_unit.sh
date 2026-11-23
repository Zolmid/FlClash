#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../android"
printf 'flutter.sdk=%s\nsdk.dir=%s\n' "$FLUTTER_ROOT" "$ANDROID_HOME" > local.properties
wrapper="$FLUTTER_ROOT/bin/cache/artifacts/gradle_wrapper"
test -d "$wrapper" || flutter precache
cp -R "$wrapper/." .
chmod +x gradlew

log="$(mktemp "${TMPDIR:-/tmp}/android-unit.XXXXXX")"
trap 'rm -f "$log"' EXIT

run_unit_tests() {
  local -a statuses
  ./gradlew :common:testDebugUnitTest :service:testDebugUnitTest :app:testDebugUnitTest \
    -Ptarget-platform=android-arm64 -x :app:compileFlutterBuildDebug -x :app:copyFlutterAssetsDebug "$@" 2>&1 | tee "$log"
  statuses=("${PIPESTATUS[@]}")
  if (( statuses[1] != 0 )); then exit "${statuses[1]}"; fi
  return "${statuses[0]}"
}

transient_dependency_failure() {
  if grep -Eqi 'checksum mismatch|SECURITY ERROR|Dependency verification failed|There were failing tests|Compilation error|Compilation failed|^e: ' "$log"; then
    return 1
  fi
  if grep -Eq "Could not (GET|HEAD) 'https://(repo\.maven\.apache\.org|plugins\.gradle\.org)/" "$log" &&
      grep -Eq 'Received status code 429 from server' "$log"; then
    return 0
  fi
  grep -Eq 'reading https://(sum\.golang\.org|proxy\.golang\.org)/[^ ]*: stream error: stream ID [0-9]+; INTERNAL_ERROR' "$log"
}

status=0
run_unit_tests "$@" || status=$?
if [ "$status" -ne 0 ] && transient_dependency_failure; then
  echo "android_unit: transient dependency download failure (exit $status); retrying once in 60s" >&2
  sleep 60
  if grep -Eq 'stream error: stream ID [0-9]+; INTERNAL_ERROR' "$log"; then
    export GODEBUG="${GODEBUG:+$GODEBUG,}http2client=0"
  fi
  status=0
  run_unit_tests "$@" || status=$?
fi
exit "$status"
