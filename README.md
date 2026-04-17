# Sonohaler Lab

A high-fidelity Flutter audio data collection app for Android, designed to record raw acoustic data from inhalers and link it to structured metadata.

## Features

- **Raw audio capture** — `AudioSource.unprocessed` disables Android's native noise suppression (NS) and auto-gain control (AGC)
- **WAV recordings** — PCM 16-bit, 44100 Hz, mono
- **Local SQLite database** — stores all metadata (flow rate, noise level, dose, distance, duration, timestamp)
- **Unique file IDs** — format `SH_XXXXX.wav`, no metadata embedded in the filename
- **Auto-stop timer** — 5 s / 10 s / 15 s options
- **History screen** — scrollable data table of all recordings
- **CSV export** — exports `sonohaler_metadata.csv` via the system share sheet

## Parameters

| Parameter | Options |
|---|---|
| Flow Rate (LPM) | 10, 20, 30, 40, 50, 60, 70, 80, 90 |
| Background Noise | Quiet, Low, Medium, High |
| Capsule Dose (mg) | 0, 10, 20, 30, 40, 50, 60 |
| Distance to Mic (cm) | 5, 10, 20, 30 |
| Timer | 5s, 10s, 15s |

## Database Schema

```sql
CREATE TABLE recordings (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id       TEXT NOT NULL,
  flow_rate     INTEGER NOT NULL,
  environment   TEXT NOT NULL,
  dose_mg       INTEGER NOT NULL,
  distance_cm   INTEGER NOT NULL,
  duration_sec  INTEGER NOT NULL,
  timestamp     TEXT NOT NULL
);
```

## Build Requirements

- Flutter SDK ≥ 3.0
- Android SDK 24+ (minSdk 24 — required for `AudioSource.UNPROCESSED`)
- Android SDK 34 (compileSdk / targetSdk)

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run on a connected Android device
flutter run

# Build a release APK
flutter build apk --release
```

## Permissions

The app requests the following permissions on first launch:

- `RECORD_AUDIO` — required for all audio capture
- `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE` (Android ≤ 12)
- `READ_MEDIA_AUDIO` (Android 13+)

## Audio File Storage

WAV files are saved to:
```
/sdcard/Android/data/com.sonohaler.lab/files/sonohaler_recordings/SH_XXXXX.wav
```

## CSV Export

The exported file is named `sonohaler_metadata.csv` and is shared via the system share sheet so you can save it to Google Drive, email it, etc. The CSV includes all columns from the recordings table.
