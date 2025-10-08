# Multi-Camera Implementation Summary

## Overview

The AVCam app now includes UI controls and visual indicators for multi-camera functionality. The multi-camera recording backend was already implemented in the codebase - this update adds user-facing controls to monitor and configure it.

## What Was Implemented

### 1. Camera Protocol Extensions (`AVCam/Model/Camera.swift`)

Added three new properties to the Camera protocol:

```swift
/// A Boolean value that indicates whether multi-camera mode is supported on this device.
var isMultiCamSupported: Bool { get }

/// A Boolean value that indicates whether multi-camera mode is currently active.
var isMultiCamActive: Bool { get }

/// The current multi-camera layout when multi-cam is active.
var multiCamLayout: MultiCameraConfiguration.MultiCamLayout { get set }
```

### 2. CameraModel Implementation (`AVCam/CameraModel.swift`)

- Implemented the protocol properties with runtime checking for AVCaptureMultiCamSession
- Uses `NSClassFromString` to safely check for multi-cam availability (works in both main app and extensions)
- `isMultiCamActive` returns true when `multiCamPreviewConfiguration` is set
- `multiCamLayout` stores the user's layout preference (defaults to Picture-in-Picture)

### 3. Multi-Camera Button (`AVCam/Views/Toolbars/FeatureToolbar/FeatureToolbar.swift`)

Added an inline multi-camera button that:
- Appears in video mode when multi-camera is supported
- Shows a menu with:
  - Current multi-camera status
  - Layout selection options (Picture-in-Picture, Side-by-Side, Grid, Custom)
  - Helpful information about multi-camera mode
- Changes icon color to blue when multi-cam is active
- Is disabled during recording to prevent mid-recording layout changes

### 4. Visual Status Indicator (`AVCam/CameraView.swift`)

Added a floating badge that appears when multi-camera is active showing:
- Multi-camera active icon
- Current layout name
- Blue background for visibility

## How It Works

### Automatic Activation

Multi-camera mode is **automatically activated** on supported devices when:
1. The device supports `AVCaptureMultiCamSession` (iPhone 11 Pro or newer)
2. The app is in video mode
3. The CaptureService successfully sets up the multi-cam session

There is no manual toggle - if your device supports it, multi-camera mode is always active during video recording.

### Layout Selection

Users can choose between four preview layouts:

1. **Picture-in-Picture** (Default)
   - Main camera fills the screen
   - Secondary camera in small overlay (top-right corner)
   - Best for focusing on one camera while monitoring the other

2. **Side-by-Side**
   - Screen split vertically
   - Both cameras get equal space
   - Good for comparing both views

3. **Grid**
   - Screen split horizontally
   - Both cameras stacked vertically
   - Alternative split view

4. **Custom**
   - Currently defaults to Picture-in-Picture
   - Can be customized in future updates

### Recording Behavior

When recording video on a multi-cam capable device:
- **Both cameras record simultaneously**
- Two separate video files are created
- Primary video: Main camera (usually back camera)
- Companion video: Secondary camera (usually front camera)
- Both files are saved to the photo library

## Testing

### On Simulator

**Important**: iOS Simulator does **NOT** support multi-camera mode.

On simulator, you will see:
- The multi-camera button appears (if device model supports it)
- Button shows "Multi-Camera Available"
- Status will show as inactive
- Only single camera preview will be visible

### On Physical Device

To test multi-camera functionality, you need:
- iPhone 11 Pro or newer (or iPad Pro 2020+)
- iOS 15.0 or later
- Physical device (not simulator)

Expected behavior:
1. Open the app
2. Switch to Video mode
3. Multi-camera button appears in the feature toolbar
4. Button icon is blue (indicating active)
5. Blue badge appears in top-right showing current layout
6. You should see both camera previews (layout depends on selection)
7. Start recording - both cameras record simultaneously
8. Stop recording - two videos are saved to photo library

## Troubleshooting

### "Multi-Camera Available" but not active

**Possible causes:**
1. **Testing on simulator** - Multi-cam is not supported on simulator
2. **Not in video mode** - Multi-cam only activates in video mode
3. **Device doesn't support it** - Requires iPhone 11 Pro or newer
4. **Session setup failed** - Check console logs for errors

### Layout changes don't appear

- Layout changes are disabled during recording
- Stop recording first, then change layout
- Layout preference is saved and will apply to next recording

### Only seeing one camera

- Check that you're on a physical device (not simulator)
- Verify device model supports multi-cam
- Check camera permissions are granted for both cameras
- Look for error messages in console logs

## File Changes Summary

### Modified Files:
1. `AVCam/Model/Camera.swift` - Added protocol properties
2. `AVCam/CameraModel.swift` - Implemented multi-cam properties
3. `AVCam/Preview Content/PreviewCameraModel.swift` - Added stub implementations
4. `AVCam/Views/Toolbars/FeatureToolbar/FeatureToolbar.swift` - Added multi-cam button
5. `AVCam/CameraView.swift` - Added status indicator badge

### No New Files Created

All functionality was added inline to existing files to avoid Xcode project configuration issues.

## Technical Notes

### Extension Compatibility

The code uses runtime checking (`NSClassFromString`) to safely reference `AVCaptureMultiCamSession` because:
- App extensions don't have access to all AVFoundation APIs
- This prevents compilation errors in extension targets
- Falls back gracefully when multi-cam is not available

### Performance Considerations

Multi-camera recording is resource-intensive:
- Uses more battery power
- Generates more heat
- Requires more memory
- May reduce maximum resolution/frame rate

The system automatically manages these constraints and may:
- Reduce quality if device gets too hot
- Limit frame rates to maintain performance
- Disable multi-cam if resources are insufficient

## Next Steps

To further enhance multi-camera functionality, consider:

1. **Add manual toggle** - Allow users to disable multi-cam even on supported devices
2. **Custom layout editor** - Let users position/resize camera previews
3. **Layout presets** - Save favorite layout configurations
4. **Performance monitoring** - Show thermal/battery status during multi-cam recording
5. **Advanced controls** - Independent exposure/focus for each camera
6. **Audio routing** - Choose which camera's audio to use

## References

- [AVCaptureMultiCamSession Documentation](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession)
- [Multi-Camera Technical Specification](./MultiCam-TechnicalSpecification.md)
- [AVFoundation Programming Guide](https://developer.apple.com/documentation/avfoundation/)

