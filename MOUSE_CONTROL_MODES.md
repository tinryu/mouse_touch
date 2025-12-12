# Mouse Control Modes

## Overview

The Screen Remote feature now supports two control modes for improved mouse control:

### 🖱️ Cursor Mode (Default)
- **Direct cursor positioning** - Touch anywhere on the screen to move the cursor to that exact position
- Similar to Chrome Remote Desktop
- Best for: Quick navigation, clicking specific UI elements, precise control
- **How it works**: Your finger position directly maps to the cursor position on the remote screen

### 🤚 Touch Mode  
- **Touchpad-style relative movement** - Drag your finger to move the cursor relative to its current position
- Similar to using a laptop touchpad
- Best for: Fine-grained control, drawing, precise adjustments
- **How it works**: Moving your finger moves the cursor in the same direction, like a touchpad

## Switching Modes

1. Tap the **Settings** button (gear icon) in the app bar
2. Find the **Control Mode** section
3. Choose between **Cursor** or **Touch**
4. The mode indicator in the info bar will update immediately

## Performance Improvements

- **Smoother movement**: Reduced throttling from 16ms to 8ms (~120 FPS)
- **Better responsiveness**: Improved gesture detection and processing
- **Adaptive sensitivity**: Touch mode has 1.2x sensitivity multiplier for comfortable control

## Visual Indicators

The bottom info bar shows your current control mode:
- 🖱️ **CURSOR** - Cursor mode active
- 🤚 **TOUCH** - Touch mode active

## Gestures

Both modes support the same gestures:

| Gesture | Action |
|---------|--------|
| Single tap | Left click |
| Single finger drag | Move cursor (mode-dependent) |
| Two finger swipe | Scroll |
| Long press | Start drag operation |
| Long press + drag | Drag and drop |

## Tips

### For Cursor Mode:
- Tap directly where you want to click
- Great for navigating menus and clicking buttons
- Fastest way to move across the screen

### For Touch Mode:
- Use small, controlled movements
- Better for tasks requiring precision
- More familiar if you're used to laptop touchpads
- Easier to make small adjustments

## Technical Details

### Cursor Mode
- Uses absolute positioning with normalized coordinates (0.0 to 1.0)
- Direct mapping: touch position → screen position
- Throttled at 8ms intervals for smooth updates

### Touch Mode  
- Uses relative positioning with delta movement
- Accumulates movement between updates
- Sensitivity: 1.2x multiplier
- Minimum threshold: 0.5 pixels to prevent jitter
- Resets position tracking when gesture ends

## Troubleshooting

**Cursor jumps around in Touch mode:**
- This is normal when starting a new gesture
- The position resets when you lift your finger
- Use smaller, continuous movements for best results

**Cursor moves too fast/slow:**
- Cursor mode: Movement is 1:1 with your touch
- Touch mode: Adjust by changing gesture speed
- Future update may add sensitivity slider

**Mode doesn't change:**
- Make sure to select the mode in Settings
- The info bar should update immediately
- If streaming, the change applies instantly
