#!/usr/bin/env python3
"""Generate native Flutter platform scaffolds without overwriting app code.

Run once after installing the current stable Flutter SDK. Re-running leaves
existing platform projects alone. CI uses the same path as a local checkout.
"""
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / 'apps/mobile'
if not shutil.which('flutter'):
    raise SystemExit('Flutter is required. Install https://docs.flutter.dev/install then rerun this script.')
if not (APP / 'android').exists() or not (APP / 'ios').exists():
    with tempfile.TemporaryDirectory(prefix='janab-flutter-') as directory:
        template = pathlib.Path(directory) / 'template'
        subprocess.run(['flutter', 'create', '--platforms=android,ios', '--project-name=quran_janab',
                        '--org=com.tahermotiwala', '--no-pub', str(template)], check=True)
        for platform in ('android', 'ios'):
            if not (APP / platform).exists():
                shutil.copytree(template / platform, APP / platform)
        if not (APP / '.metadata').exists():
            shutil.copy2(template / '.metadata', APP / '.metadata')

manifest = APP / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text()
permissions = ''.join(f'    <uses-permission android:name="android.permission.{p}" />\n'
                      for p in ['INTERNET', 'RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS']
                      if f'android.permission.{p}' not in text)
if permissions:
    index = text.index('>') + 1
    text = text[:index] + '\n' + permissions + text[index:]
text = text.replace('android:label="quran_janab"', 'android:label="Qur’an Janab"')
manifest.write_text(text)

debug_manifest = APP / 'android/app/src/debug/AndroidManifest.xml'
debug_manifest.parent.mkdir(parents=True, exist_ok=True)
debug_manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <application android:usesCleartextTraffic="true" />
</manifest>
''')
for gradle in [APP / 'android/app/build.gradle.kts', APP / 'android/app/build.gradle']:
    if gradle.exists():
        text = gradle.read_text().replace('flutter.minSdkVersion', '23')
        gradle.write_text(text)

plist = APP / 'ios/Runner/Info.plist'
text = plist.read_text()
if 'NSMicrophoneUsageDescription' not in text:
    text = text.replace('</dict>', '<key>NSMicrophoneUsageDescription</key>\n'
                        '<string>Listen to your recitation during an active practice session.</string>\n</dict>')
text = text.replace('<string>Quran Janab</string>', '<string>Qur’an Janab</string>')
plist.write_text(text)
print('Native Android/iOS scaffolds ready. Next: cd apps/mobile && flutter pub get')
