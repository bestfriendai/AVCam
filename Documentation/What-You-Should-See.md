# What You Should See - Multi-Camera Feature

## Current Setup: iPhone 17 Pro Max Simulator (iOS 26)

### When You Launch the App

1. **App Opens Successfully** ✅
   - Camera preview appears
   - Single camera view (back camera by default)
   - All UI elements visible

2. **Switch to Video Mode**
   - Swipe or tap to switch from Photo to Video mode
   - Feature toolbar appears at the top

3. **Multi-Camera Button Appears** ✅
   - Location: Top toolbar (feature toolbar)
   - Icon: ⚠️ Orange warning triangle
   - This indicates simulator limitation

4. **Tap the Multi-Camera Button**
   - Menu opens with:
     - ⚠️ "Simulator Limitation"
     - Message: "Multi-camera is not supported on iOS Simulator. Test on a physical device (iPhone 11 Pro or newer)."
     - 📱 "Test on Real Device" info item

### What You WON'T See on Simulator

❌ Blue multi-camera icon
❌ "Multi-Camera Active" status
❌ Dual camera preview (both front and back)
❌ Blue status badge
❌ Layout selection options
❌ Simultaneous recording from both cameras

### Why?

**iOS Simulator does not support AVCaptureMultiCamSession**, regardless of which device you simulate. This is a fundamental limitation - even simulating an iPhone 17 Pro Max won't enable multi-camera because the simulator doesn't have access to physical camera hardware.

---

## On Physical Device: iPhone 11 Pro or Newer

### When You Launch the App

1. **App Opens Successfully** ✅
   - Camera preview appears
   - If multi-cam is supported, you'll see both cameras

2. **Switch to Video Mode**
   - Swipe or tap to switch to Video mode
   - Feature toolbar appears

3. **Multi-Camera Button Appears** ✅
   - Location: Top toolbar (feature toolbar)
   - Icon: 📹 Blue video camera with checkmark
   - This indicates multi-camera is ACTIVE

4. **Visual Indicators**
   - Blue status badge in top-right corner
   - Shows current layout (e.g., "PiP" for Picture-in-Picture)
   - Badge has blue background

5. **Camera Preview**
   - **Picture-in-Picture (Default)**:
     - Main camera fills entire screen
     - Small overlay in top-right showing other camera
     - Overlay has rounded corners and white border
   
   - **Side-by-Side**:
     - Screen split vertically
     - Left half: One camera
     - Right half: Other camera
   
   - **Grid**:
     - Screen split horizontally
     - Top half: One camera
     - Bottom half: Other camera

6. **Tap the Multi-Camera Button**
   - Menu opens with:
     - ✅ "Multi-Camera Active"
     - "Recording from both cameras"
     - **Preview Layout** section with options:
       - Picture in Picture (with icon)
       - Side by Side (with icon)
       - Grid (with icon)
       - Custom (with icon)
     - Checkmark next to currently selected layout
     - ℹ️ "Dual Camera Recording" info

7. **Select a Different Layout**
   - Tap any layout option
   - Preview immediately updates to show new layout
   - Status badge updates to show new layout name
   - Menu closes

8. **Start Recording**
   - Tap red record button
   - Both cameras start recording simultaneously
   - Recording indicator appears
   - Multi-camera button becomes disabled (grayed out)
   - Layout is locked during recording

9. **Stop Recording**
   - Tap stop button
   - Both recordings stop
   - Multi-camera button becomes enabled again
   - Two video files are saved to Photos

10. **Check Photos App**
    - Open Photos app
    - Find the two most recent videos
    - One from primary camera (usually back)
    - One from secondary camera (usually front)
    - Both videos have same duration
    - Both videos are synchronized

---

## Visual Comparison

### Simulator View
```
┌─────────────────────────────┐
│  ⚠️  [HDR]                  │  ← Orange warning icon
├─────────────────────────────┤
│                             │
│                             │
│    Single Camera Preview    │
│    (Back Camera Only)       │
│                             │
│                             │
├─────────────────────────────┤
│     [Photo] [Video]         │
│         (O)                 │  ← Record button
└─────────────────────────────┘
```

### Physical Device View (Picture-in-Picture)
```
┌─────────────────────────────┐
│  📹  [HDR]    [📹 PiP]      │  ← Blue icon + status badge
├─────────────────────────────┤
│                 ┌─────────┐ │
│                 │ Front   │ │  ← Small overlay
│                 │ Camera  │ │
│   Back Camera   └─────────┘ │
│   (Full Screen)             │
│                             │
│                             │
├─────────────────────────────┤
│     [Photo] [Video]         │
│         (O)                 │
└─────────────────────────────┘
```

### Physical Device View (Side-by-Side)
```
┌─────────────────────────────┐
│  📹  [HDR]  [📹 Side by Side]│
├─────────────────────────────┤
│            │                │
│   Back     │    Front       │
│  Camera    │   Camera       │
│            │                │
│            │                │
│            │                │
├─────────────────────────────┤
│     [Photo] [Video]         │
│         (O)                 │
└─────────────────────────────┘
```

### Physical Device View (Grid)
```
┌─────────────────────────────┐
│  📹  [HDR]    [📹 Grid]     │
├─────────────────────────────┤
│                             │
│      Back Camera            │
│                             │
├─────────────────────────────┤
│                             │
│      Front Camera           │
│                             │
├─────────────────────────────┤
│     [Photo] [Video]         │
│         (O)                 │
└─────────────────────────────┘
```

---

## Button States

### Multi-Camera Button Icon States

| State | Icon | Color | Meaning |
|-------|------|-------|---------|
| Active | 📹 video.fill.badge.checkmark | Blue | Multi-cam is recording/ready |
| Simulator | ⚠️ exclamationmark.triangle | Orange | Running on simulator |
| Not Supported | ➕ video.badge.plus | White | Device doesn't support multi-cam |

### Multi-Camera Button Enabled/Disabled

| Scenario | Enabled | Reason |
|----------|---------|--------|
| Not recording | ✅ Yes | Can change layout |
| Recording | ❌ No | Layout locked during recording |
| Simulator | ✅ Yes | Can view info/warning |

---

## Expected Behavior Summary

### ✅ What SHOULD Work on Simulator
- App launches
- Single camera preview
- Photo capture
- Video recording (single camera)
- UI navigation
- Multi-camera button appears
- Warning message displays

### ❌ What WON'T Work on Simulator
- Multi-camera preview
- Dual camera recording
- Layout switching (no dual preview to switch)
- Blue "active" status
- Status badge

### ✅ What SHOULD Work on Physical Device (iPhone 11 Pro+)
- Everything that works on simulator, PLUS:
- Multi-camera preview (both cameras visible)
- Layout switching (PiP, Side-by-Side, Grid, Custom)
- Blue active status indicator
- Status badge showing current layout
- Simultaneous recording from both cameras
- Two video files saved to Photos
- Synchronized playback of both videos

---

## Troubleshooting

### "I don't see the multi-camera button at all"
- Make sure you're in **Video mode** (not Photo mode)
- Multi-camera button only appears in video mode

### "I see the button but it's orange with a warning"
- You're on simulator - this is expected
- Deploy to a physical device to test multi-camera

### "I'm on a real device but still see the warning"
- Check device model - must be iPhone 11 Pro or newer
- Check iOS version - must be iOS 13.0 or later
- Check camera permissions - must be granted

### "I see dual preview but can't change layout during recording"
- This is intentional - layout is locked during recording
- Stop recording first, then change layout

### "Only one video saved after recording"
- Check if multi-camera was actually active (blue icon)
- Check device compatibility
- Check console logs for errors

---

## Quick Reference

**To test multi-camera on simulator**: Not possible - will show warning ⚠️

**To test multi-camera on real device**:
1. Deploy to iPhone 11 Pro or newer
2. Grant camera permissions
3. Switch to Video mode
4. Look for blue 📹 icon
5. See both camera previews
6. Tap button to change layout
7. Record video
8. Check Photos for two videos

**Current implementation status**: ✅ Complete and correct

**Simulator limitation**: ⚠️ Multi-camera not supported on any simulator

