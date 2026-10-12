# ResQ — Flutter prototype

Prototype modular ResQ app with Firebase Auth/Firestore, OpenStreetMap, BMKG earthquake feed, report hashing, survival mini-game, local profile data, and sensor-trigger simulation.

## Run
1. Install Flutter stable and run `flutter pub get`.
2. Create a Firebase project. Enable Email/Password in Authentication and create Firestore.
3. Run `dart pub global activate flutterfire_cli` then `flutterfire configure` from this directory. This generates `lib/firebase_options.dart`.
4. In `lib/main.dart`, uncomment the `firebase_options.dart` import and replace `Firebase.initializeApp()` with `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
5. Run `flutter run`.

Without Firebase configuration, the app intentionally does not silently pretend cloud login/reporting works. Configure Firebase before testing authentication and report submission.

## Platform notes
- Add Android internet permission if missing: `<uses-permission android:name="android.permission.INTERNET"/>` in `android/app/src/main/AndroidManifest.xml`.
- For location access, add platform location permissions and request them before using GPS. The map currently uses a safe default center and demo shelter markers.
- Sensor monitoring is foreground-oriented. Android background sensor execution requires a foreground service and platform-specific lifecycle/permission work; this prototype does not claim to run reliably after the OS kills/suspends the app.
- A phone's light sensor can be absent or unavailable. Developer Override is provided for demonstrations.
- SHA-256 is an integrity fingerprint, not blockchain and not proof that a report is true. Timestamp/location hashing can be recomputed by a malicious client; production systems should hash server-side and apply verification/moderation.
- Never rely on this prototype as a sole emergency alert system. Verify local emergency information independently.
