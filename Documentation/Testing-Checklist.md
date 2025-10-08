# Multi-Camera Testing Checklist

## Pre-Testing Setup

- [ ] Deploy app to **physical device** (iPhone 11 Pro or newer)
- [ ] Grant **camera permissions** when prompted
- [ ] Grant **microphone permissions** when prompted
- [ ] Grant **photo library permissions** when prompted
- [ ] Ensure device has **sufficient storage** (at least 1GB free)
- [ ] Ensure device **battery level** is above 20%

## Basic Multi-Camera Functionality

### Activation
- [ ] Launch app successfully
- [ ] Switch to **Video mode**
- [ ] Multi-camera button appears in **top toolbar**
- [ ] Button icon is **blue** (video.fill.badge.checkmark)
- [ ] Blue status badge appears in **top-right corner**
- [ ] Badge shows current layout (e.g., "PiP")

### Preview
- [ ] **Both camera previews** are visible
- [ ] Primary camera (rear) shows full or split view
- [ ] Secondary camera (front) shows in overlay or split view
- [ ] Previews update in real-time
- [ ] No lag or stuttering in previews

### Layout Switching
- [ ] Tap multi-camera button to open menu
- [ ] Menu shows "Multi-Camera Active" status
- [ ] Four layout options visible:
  - [ ] Picture in Picture
  - [ ] Side by Side
  - [ ] Grid
  - [ ] Custom
- [ ] Current layout has checkmark
- [ ] Select **Picture in Picture**:
  - [ ] Small overlay appears in corner
  - [ ] Overlay has rounded corners
  - [ ] Overlay has white border
  - [ ] Badge updates to "PiP"
- [ ] Select **Side by Side**:
  - [ ] Screen splits vertically
  - [ ] Both cameras equal size
  - [ ] No gap between previews
  - [ ] Badge updates to "Side by Side"
- [ ] Select **Grid**:
  - [ ] Screen splits horizontally
  - [ ] Both cameras equal size
  - [ ] No gap between previews
  - [ ] Badge updates to "Grid"
- [ ] Select **Custom**:
  - [ ] Layout changes (currently same as PiP)
  - [ ] Badge updates to "Custom"

## Recording Functionality

### Start Recording
- [ ] Tap red **record button**
- [ ] Recording indicator appears
- [ ] Timer starts counting
- [ ] Multi-camera button becomes **disabled** (grayed out)
- [ ] Layout is **locked** (cannot change during recording)
- [ ] Both camera previews continue updating
- [ ] No dropped frames or stuttering

### During Recording
- [ ] Recording timer updates every second
- [ ] Both previews remain active
- [ ] Can switch between front/back camera (if supported)
- [ ] Audio is being captured
- [ ] No thermal warnings (for short recordings)
- [ ] Battery drains at expected rate

### Stop Recording
- [ ] Tap **stop button**
- [ ] Recording stops immediately
- [ ] Timer stops
- [ ] Multi-camera button becomes **enabled** again
- [ ] Can change layout again
- [ ] Thumbnail appears in bottom-left corner

### Verify Saved Videos
- [ ] Open **Photos app**
- [ ] Find the two most recent videos
- [ ] **Primary video** (rear camera):
  - [ ] Video plays correctly
  - [ ] Audio is present
  - [ ] Duration matches recording time
  - [ ] Quality is good
  - [ ] No corruption
- [ ] **Secondary video** (front camera):
  - [ ] Video plays correctly
  - [ ] Duration matches primary video
  - [ ] Quality is good
  - [ ] No corruption
  - [ ] Synchronized with primary video
- [ ] Both videos have same timestamp
- [ ] Both videos saved to same album

## Advanced Features

### Video Stabilization
- [ ] Record while walking
- [ ] Primary video has stabilization
- [ ] Secondary video has stabilization
- [ ] Footage is smooth

### Different Layouts
- [ ] Record in **Picture in Picture** layout
  - [ ] Both videos saved
  - [ ] Layout doesn't affect video content
- [ ] Record in **Side by Side** layout
  - [ ] Both videos saved
  - [ ] Layout doesn't affect video content
- [ ] Record in **Grid** layout
  - [ ] Both videos saved
  - [ ] Layout doesn't affect video content

### Multiple Recordings
- [ ] Record first video
- [ ] Stop recording
- [ ] Change layout
- [ ] Record second video
- [ ] Stop recording
- [ ] All four videos saved (2 pairs)

### Photo Capture (Single Camera)
- [ ] Switch to **Photo mode**
- [ ] Multi-camera button **disappears** (expected)
- [ ] Only single camera preview
- [ ] Take photo successfully
- [ ] Photo saved to library

## Error Handling

### Interruptions
- [ ] Start recording
- [ ] Receive phone call
  - [ ] Recording stops gracefully
  - [ ] Video saved up to interruption point
  - [ ] App recovers after call ends
- [ ] Start recording
- [ ] Lock device
  - [ ] Recording continues (if supported)
  - [ ] Or stops gracefully
- [ ] Start recording
- [ ] Switch to another app
  - [ ] Recording stops
  - [ ] Video saved

### Resource Constraints
- [ ] Record until storage is low
  - [ ] Warning appears (if implemented)
  - [ ] Recording stops gracefully
  - [ ] Videos saved
- [ ] Record until battery is low
  - [ ] System warning appears
  - [ ] Recording continues or stops gracefully
- [ ] Record until device is hot
  - [ ] Thermal warning may appear
  - [ ] Recording may stop automatically
  - [ ] App remains stable

### Permission Issues
- [ ] Revoke camera permission
  - [ ] App shows permission request
  - [ ] Cannot access camera
- [ ] Revoke microphone permission
  - [ ] Video records without audio
  - [ ] Or shows permission request
- [ ] Revoke photo library permission
  - [ ] Cannot save videos
  - [ ] Or shows permission request

## Performance Testing

### Short Recordings (< 30 seconds)
- [ ] No lag or stuttering
- [ ] Smooth preview
- [ ] Quick save to library
- [ ] No thermal issues
- [ ] Minimal battery drain

### Medium Recordings (1-2 minutes)
- [ ] Consistent performance
- [ ] No dropped frames
- [ ] Smooth preview throughout
- [ ] Successful save
- [ ] Moderate battery drain
- [ ] Slight device warming (normal)

### Long Recordings (5+ minutes)
- [ ] Performance remains stable
- [ ] No crashes
- [ ] Videos save successfully
- [ ] Device may get warm (expected)
- [ ] Battery drains faster (expected)
- [ ] May hit thermal limits (device-dependent)

## UI/UX Testing

### Visual Feedback
- [ ] Multi-camera button clearly visible
- [ ] Status badge clearly visible
- [ ] Badge text readable
- [ ] Icons are appropriate
- [ ] Colors are correct (blue for active)
- [ ] Animations are smooth

### Menu Interaction
- [ ] Menu opens quickly
- [ ] Menu items are readable
- [ ] Checkmark shows current selection
- [ ] Menu closes after selection
- [ ] Menu closes when tapping outside

### Accessibility
- [ ] VoiceOver reads button labels
- [ ] VoiceOver reads menu items
- [ ] Dynamic Type supported
- [ ] High contrast mode works
- [ ] Reduce motion respected

## Edge Cases

### Device Rotation
- [ ] Rotate device during preview
  - [ ] Previews adjust correctly
  - [ ] Layout maintains
- [ ] Rotate device during recording
  - [ ] Recording continues
  - [ ] Orientation captured correctly

### Camera Switching
- [ ] Switch primary camera (if multiple rear cameras)
  - [ ] Multi-camera remains active
  - [ ] Preview updates
- [ ] Cannot switch to front as primary (front is secondary)

### Background/Foreground
- [ ] Send app to background
  - [ ] Preview stops
  - [ ] Recording stops (if active)
- [ ] Bring app to foreground
  - [ ] Preview resumes
  - [ ] Multi-camera reactivates

### Memory Pressure
- [ ] Open many apps
- [ ] Return to camera app
  - [ ] App resumes correctly
  - [ ] Multi-camera reactivates
  - [ ] No crashes

## Compatibility Testing

### Different Devices
- [ ] iPhone 11 Pro
- [ ] iPhone 12 Pro
- [ ] iPhone 13 Pro
- [ ] iPhone 14 Pro
- [ ] iPhone 15 Pro
- [ ] iPhone 16 Pro
- [ ] iPhone 17 Pro Max (your device)
- [ ] iPad Pro (if available)

### Different iOS Versions
- [ ] iOS 15.x
- [ ] iOS 16.x
- [ ] iOS 17.x
- [ ] iOS 18.x
- [ ] iOS 26.x (your version)

## Console Logs

### Expected Logs
- [ ] "Multi-camera session configured successfully" (or similar)
- [ ] No error messages during normal operation
- [ ] Performance metrics logged (if enabled)

### Error Logs to Watch For
- [ ] "Multi-cam configuration failed"
- [ ] "Falling back to single-camera session"
- [ ] "Failed to configure multi-camera format"
- [ ] AVFoundation errors
- [ ] Memory warnings

## Final Verification

- [ ] All basic features work
- [ ] All advanced features work
- [ ] No crashes during testing
- [ ] No data loss
- [ ] Performance is acceptable
- [ ] UI is responsive
- [ ] Videos are high quality
- [ ] Audio is clear
- [ ] Synchronization is correct

## Known Limitations

- [ ] Multi-camera only works in **Video mode** (not Photo mode)
- [ ] Multi-camera requires **iPhone 11 Pro or newer**
- [ ] Multi-camera **not supported on simulator**
- [ ] Layout locked during recording
- [ ] Higher battery drain than single camera
- [ ] Higher thermal load than single camera
- [ ] May reduce maximum recording duration on some devices

## Report Issues

If any test fails, note:
- [ ] Device model
- [ ] iOS version
- [ ] Steps to reproduce
- [ ] Expected behavior
- [ ] Actual behavior
- [ ] Console logs
- [ ] Screenshots/screen recordings

---

## Quick Test (5 minutes)

For a quick verification:

1. [ ] Launch app on physical device
2. [ ] Switch to Video mode
3. [ ] Verify blue multi-camera button appears
4. [ ] Verify both camera previews visible
5. [ ] Change layout to Side by Side
6. [ ] Record 10-second video
7. [ ] Stop recording
8. [ ] Open Photos app
9. [ ] Verify two videos saved
10. [ ] Play both videos to confirm quality

If all 10 steps pass, basic multi-camera functionality is working! ✅

