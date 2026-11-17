import glob
import re

M = 'android/app/src/main/AndroidManifest.xml'
s = open(M, encoding='utf-8').read()

if 'xmlns:tools' not in s:
    s = s.replace(
        'xmlns:android="http://schemas.android.com/apk/res/android"',
        'xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"',
        1,
    )

perms = ['INTERNET', 'WAKE_LOCK', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK']
add = ''.join(
    '    <uses-permission android:name="android.permission.%s"/>\n' % p
    for p in perms
    if ('android.permission.%s"' % p) not in s
)
s = s.replace('<application', add + '    <application', 1)

if 'com.ryanheise.audioservice.AudioService' not in s:
    svc = '''        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    '''
    s = s.replace('</application>', svc + '</application>', 1)

if 'usesCleartextTraffic' not in s:
    s = s.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="Vycustic"', s, count=1)
open(M, 'w', encoding='utf-8').write(s)

for f in glob.glob('android/app/src/main/**/MainActivity.*', recursive=True):
    t = open(f, encoding='utf-8').read()
    t = t.replace('import io.flutter.embedding.android.FlutterActivity',
                  'import com.ryanheise.audioservice.AudioServiceActivity')
    t = t.replace('FlutterActivity()', 'AudioServiceActivity()')
    open(f, 'w', encoding='utf-8').write(t)

print('manifest patched')
