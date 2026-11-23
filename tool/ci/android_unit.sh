#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../android"
printf 'flutter.sdk=%s\nsdk.dir=%s\n' "$FLUTTER_ROOT" "$ANDROID_HOME" > local.properties
wrapper="$FLUTTER_ROOT/bin/cache/artifacts/gradle_wrapper"
test -d "$wrapper" || flutter precache
cp -R "$wrapper/." .
chmod +x gradlew
./gradlew :common:testDebugUnitTest :service:testDebugUnitTest :app:testDebugUnitTest \
  -Ptarget-platform=android-arm64 -x :app:compileFlutterBuildDebug -x :app:copyFlutterAssetsDebug "$@"
