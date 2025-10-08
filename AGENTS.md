# Repository Guidelines

## Project Structure & Module Organization
The main SwiftUI app lives in `AVCam/`, with `AVCamApp.swift` bootstrapping `CameraModel` and `CameraView`. Capture actors and delegates reside in `AVCam/Capture/`, while supporting value types and intents are under `AVCam/Model/`. Reusable interface components sit in `AVCam/Views/`, and shared resources live in `Assets.xcassets`, `Preview Content`, and `Support`. Lock Screen integrations are split into `AVCamCaptureExtension/` and `AVCamControlCenterExtension/`, and shared configuration defaults sit in `Configuration/SampleCode.xcconfig`.

## Build, Test, and Development Commands
- `open AVCam.xcodeproj` launches the project in Xcode; choose the `AVCam`, `AVCamCaptureExtension`, or `AVCamControlCenterExtension` scheme before building.
- `xcodebuild -scheme AVCam -destination 'platform=iOS,name=<Device Name>' build` performs a device build once signing is configured.
- `xcodebuild -scheme AVCam -destination 'platform=iOS,name=<Device Name>' test` currently verifies compilation; add XCTest targets here when automated coverage is introduced.
- `xcodebuild -list -project AVCam.xcodeproj` enumerates available schemes when you need to confirm target names.

## Coding Style & Naming Conventions
Follow Swift API design guidelines: 4-space indentation, `UpperCamelCase` types, `lowerCamelCase` properties and functions, and descriptive, verb-first async methods (for example, `startRecording()`). Prefer Swift concurrency (`async`/`await`, actors) over GCD, and keep documentation comments in Apple-style complete sentences. Run Xcode’s “Re-Indent” and “Fix All Issues” commands before committing.

## Testing Guidelines
Automated tests are not yet provided, so every change must be exercised on a physical iOS device running iOS 18 or later. Validate photo capture, movie capture, and switching between rear and front cameras. When touching extensions, launch them from Control Center and the Lock Screen to confirm they respect `CameraState` synchronization. Blocked features should be guarded with runtime availability checks to keep manual smoke tests fast.

## Commit & Pull Request Guidelines
Recent history favors concise, capitalized summaries (for example, “Added support for the Camera Control”). Use the imperative mood when possible and avoid stacking multiple concerns in one commit. Pull requests must call out the impacted targets, list manual test devices and results, and include screenshots or screen recordings when UI changes are visible. Link any associated Feedback IDs or issues, and confirm signing changes in the description.

## Signing & Configuration Tips
Each target requires a valid development team; set it in the target’s Signing & Capabilities tab before running. Keep custom entitlements inside the project and never commit personal provisioning profiles. Use `Configuration/SampleCode.xcconfig` for shared overrides instead of editing build settings directly.
