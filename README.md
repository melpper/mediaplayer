# Loop Player — Clean Android Video Player

A minimal, distraction-free MP4 player for Android. No scrollbars, no clutter — just your video, looping.

## Features
- 🎬 Plays MP4 (and MKV, MOV, AVI, WEBM) videos
- 🔁 Seamless looping — single video loops forever, playlists loop around
- ➕ Add multiple videos, reorder by drag & drop, remove any time
- 🖥️ Fullscreen immersive mode — no status bar, no navigation bar
- 💡 Screen stays on during playback (wakelock)
- 👆 Tap to show/hide controls — auto-hides after 3 seconds
- ⏮⏯⏭ Playlist navigation with prev/next
- 💾 Playlist saved between sessions

## Setup & Build

### Requirements
- Flutter 3.x
- Android SDK (minSdk 21 / Android 5+)

### Steps

```bash
# 1. Clone / unzip the project
cd video_player_app

# 2. Get dependencies
flutter pub get

# 3. Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

Install the APK on your Android device:
```bash
flutter install
# or transfer the APK and install manually
```

## How to Use

1. Open **Loop Player**
2. Tap **+** (top right) to pick one or more videos from your device
3. Tap a video or **PLAY ALL** to start
4. In the player: **tap screen** to show controls
5. Controls auto-hide after 3 seconds
6. Use ⏮ / ⏭ to jump between videos in the playlist
7. Everything loops automatically

## Permissions
- `READ_EXTERNAL_STORAGE` / `READ_MEDIA_VIDEO` — to access your video files
- `WAKE_LOCK` — keeps screen on during playback

## Project Structure
```
lib/
  main.dart              # App entry, immersive mode setup
  screens/
    home_screen.dart     # Playlist manager
    player_screen.dart   # Fullscreen player with controls
android/
  app/src/main/
    AndroidManifest.xml  # Permissions & file provider
    res/xml/file_paths.xml
pubspec.yaml             # Dependencies
```

## Key Dependencies
| Package | Purpose |
|---|---|
| `video_player` | Core video playback |
| `file_picker` | Browse & pick video files |
| `shared_preferences` | Persist playlist across sessions |
| `wakelock_plus` | Keep screen awake |
| `path` | File name utilities |
