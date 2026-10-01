#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter create . --org br.ufpb.lema --project-name odin_app --platforms android,ios

MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi

flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
