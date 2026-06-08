---
name: build-lightweight-flutter-android
description: Build, extend, debug, and validate lightweight Flutter Android utilities that use native Kotlin channels, local files, MediaStore or FileProvider, FFmpeg, progress and cancellation, low-memory safeguards, APK size controls, and real-device workflows. Use for small local-first Android apps where dependency weight, storage semantics, permissions, licenses, Gradle memory, ABI packaging, and end-to-end user behavior matter.
---

# Build Lightweight Flutter Android

## Workflow

1. Inspect the repository before choosing dependencies or architecture.
2. Restate the user's complete real-device workflow and observable success condition.
3. Separate Flutter behavior, Android platform behavior, and third-party app behavior.
4. Choose the smallest implementation that matches existing project patterns.
5. Implement one vertical slice through UI, service, native channel, persistence, and cleanup.
6. Validate Dart, Kotlin, manifests, tests, APK contents, and a real-device scenario.
7. Report changed files, verified behavior, and anything that still requires device testing.

## Clarify The User Flow

Before high-cost edits, determine:

- Where does the input originate?
- Where must the result appear?
- Does "share" mean media preview or original file attachment?
- Does "save" mean app-private storage, MediaStore, Downloads, or a third-party app copy?
- How will the user decide that conversion succeeded?

Do not implement public gallery export merely because a converted image was not visible after
another app re-saved it. Read [android-boundaries.md](references/android-boundaries.md) when storage,
sharing, permissions, gallery visibility, or file extensions are involved.

## Keep The App Lightweight

- Prefer existing project patterns and Android framework APIs.
- Avoid databases when a bounded JSON file is enough.
- Avoid large Flutter plugins when a small `MethodChannel` is clearer.
- Run heavy native work off the Android main thread.
- Stream progress through `EventChannel`; expose cancellation explicitly.
- Set input size, duration, pixel, disk-space, and concurrency limits.
- Split release APKs by ABI when native libraries dominate size.
- Preserve existing Gradle heap, worker, AGP, and Kotlin constraints unless requested otherwise.

## Handle Native Files Correctly

- Treat filesystem paths and `content://` URIs as different types.
- Use `FileProvider` only for configured roots and grant read permission.
- Verify the actual directory returned by `path_provider` on Android.
- Use MediaStore for public media, SAF for user-selected destinations, and private directories for
  internal results.
- Define whether deletion removes the private source, public copy, history record, or all three.
- When sharing an original converted file, consider a generic file MIME to discourage chat apps from
  treating it as compressible media.

## Evaluate Native Dependencies

Before adding FFmpeg or another AAR:

1. Check maintenance status and artifact availability.
2. Check LGPL/GPL and codec-specific licensing.
3. Check required codecs in the actual binary.
4. Inspect transitive dependencies and manifest permissions.
5. Check supported ABIs and Android page-size compatibility.
6. Build release APKs and measure per-ABI size.
7. Keep a manual artifact fallback when network reliability is poor.

## Validate In Layers

Follow [validation-checklist.md](references/validation-checklist.md).

Minimum completion gate:

```text
format -> analyze -> tests -> release build -> APK inspection -> real-device workflow
```

Distinguish:

- code-complete
- build-verified
- device-verified
- user-flow-verified

## Diagnose Vibe Coding Failures

When feedback contradicts tests:

1. Reconstruct the exact taps and apps involved.
2. Identify which component created the observed file.
3. Inspect paths, URIs, MIME types, extensions, and file headers.
4. Reproduce the boundary rather than adding features speculatively.
5. Revert wrong-direction work cleanly before proceeding.

Prefer one corrected model of the workflow over defensive features that hide the real cause.

## Report Work

Include:

- behavior implemented
- files changed
- tests and builds run
- APK path, version, ABI, size, and permissions
- license or device risks
- exact remaining manual verification steps
