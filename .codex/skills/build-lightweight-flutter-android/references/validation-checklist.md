# Validation Checklist

## Before editing

- Read `pubspec.yaml`, Gradle settings, manifests, services, models, and relevant pages.
- Check dirty or user-owned changes.
- Record heap, worker, AGP, Kotlin, minSdk, targetSdk, and ABI constraints.
- Define the real-device acceptance steps.

## Dart and Flutter

- Run formatter.
- Run `flutter analyze`.
- Run all unit and widget tests.
- Add tests for parsing, channel arguments, cancellation, corrupt data, and boundary rejection.

## Kotlin and Android

- Compile every changed native channel.
- Keep disk or codec work off the main thread.
- Delete partial output on error or cancellation.
- Map native exceptions to short user-facing messages.
- Check manifest merge output and packaged XML.

## Files and sharing

- Confirm the output exists and has nonzero size.
- Confirm the extension matches requested format.
- Inspect magic bytes when format correctness matters.
- Open through the same FileProvider URI used on-device.
- Share as media and original file only when both behaviors are intentional.
- Test missing files, empty paths, corrupt input, duplicate names, and deletion.

## FFmpeg

- Verify the expected encoder string in the native library.
- Confirm progress moves and cancellation terminates the session.
- Limit threads and map only required streams.
- Test no-audio video, damaged video, short video, and a large file.
- Inspect license files and third-party notices.

## APK

- Build release, not only debug.
- Split per ABI when native libraries are large.
- Check application label, version code, version name, minSdk, targetSdk, permissions, and native ABI.
- Record size and SHA-256.
- Install as an upgrade over the previous version.

## Device acceptance

- Test on a real Android phone.
- Repeat the user's exact workflow, including receiving apps such as WeChat.
- Distinguish app output from copies created by another app.
- Capture screenshots and exact error text.
- Mark completion only after the final observable behavior is confirmed.
