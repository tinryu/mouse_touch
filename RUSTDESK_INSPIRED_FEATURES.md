# RustDesk-Inspired Features

This document describes the RustDesk-inspired enhancements added to the mouse_touch remote desktop application.

## Overview

We've enhanced the existing custom Node.js server and Flutter client with features inspired by RustDesk's proven remote desktop technology, including multi-codec support, adaptive streaming, and network quality monitoring.

## New Features

### 1. Multi-Codec Support

The server now supports multiple video codecs for screen streaming:

- **JPEG** (default) - Best compatibility, works on all platforms
- **VP8** - Good quality with low latency (requires ffmpeg)
- **VP9** - Better compression than VP8 (requires ffmpeg)
- **H.264** - Hardware accelerated on many devices (requires ffmpeg)

**How to use:**
1. Connect to the server
2. Open Settings (gear icon)
3. Select your preferred codec from the dropdown
4. Click "Apply Settings" to restart the stream with the new codec

### 2. Adaptive Quality Streaming

The server automatically adjusts stream quality and frame rate based on network conditions:

- **Excellent network** (< 50ms latency): Increases quality and FPS
- **Good network** (< 150ms latency): Maintains current settings
- **Fair network** (< 300ms latency): Reduces quality slightly
- **Poor network** (> 300ms latency): Significantly reduces quality and FPS

This ensures smooth streaming even on unstable connections.

### 3. Network Quality Monitoring

Real-time network quality indicator shows connection status:

- 🟢 **EXCELLENT** - Latency < 50ms
- 🟢 **GOOD** - Latency < 150ms
- 🟠 **FAIR** - Latency < 300ms
- 🔴 **POOR** - Latency > 300ms

The indicator is visible in the bottom info bar during streaming.

### 4. Enhanced Statistics Display

The info bar now shows:

**Top row:**
- Resolution (e.g., 1920x1080)
- Current codec (JPEG/VP8/VP9/H264)
- Network quality with color indicator

**Bottom row:**
- FPS: Current/Target (e.g., 8/10 - orange if below target)
- Quality: Current/Target (e.g., 65%/70% - orange if below target)
- Latency in milliseconds

### 5. Automatic Performance Adaptation

The system automatically adapts to network conditions:

- **Quality adjustment**: Ranges from 40% to 90% based on network
- **FPS adjustment**: Ranges from 5 to 30 FPS based on network
- **Adjustments every 10 frames**: Smooth transitions without jarring changes

## Configuration

### Server Configuration (`config.js`)

```javascript
compression: {
  codec: 'jpeg',              // Default codec
  quality: 70,                // Default quality (1-100)
  
  adaptive: {
    enabled: true,            // Enable adaptive streaming
    targetLatency: 100,       // Target latency in ms
    minBitrate: '500k',       // Minimum bitrate
    maxBitrate: '3M',         // Maximum bitrate
  }
}

performance: {
  networkMonitoring: {
    enabled: true,            // Monitor network quality
    latencyThreshold: {
      good: 50,               // < 50ms = excellent
      fair: 150,              // < 150ms = good
      poor: 300               // < 300ms = fair
    }
  }
}
```

### Client Settings

Access via the Settings button (gear icon) in the app:

- **Frame Rate**: 5-30 FPS (default: 10)
- **Quality**: 40-90% (default: 70)
- **Codec**: JPEG/VP8/VP9/H264 (default: JPEG)

## Performance Tips

### For Best Quality
- Use H.264 codec if your device supports hardware decoding
- Set quality to 80-90%
- Set FPS to 20-30
- Ensure good network connection (WiFi recommended)

### For Best Performance (Low-end devices)
- Use JPEG codec
- Set quality to 50-60%
- Set FPS to 10-15
- Let adaptive streaming handle the rest

### For Low Bandwidth
- Use VP9 codec (best compression)
- Set quality to 60-70%
- Set FPS to 10
- Enable adaptive streaming (enabled by default)

## Codec Comparison

| Codec | Quality | Speed | Bandwidth | Hardware Support |
|-------|---------|-------|-----------|------------------|
| JPEG  | Good    | Fast  | High      | Universal        |
| VP8   | Better  | Fast  | Medium    | Limited          |
| VP9   | Best    | Medium| Low       | Limited          |
| H.264 | Better  | Fast  | Medium    | Excellent        |

## Troubleshooting

### Video codecs (VP8/VP9/H264) not available

The server requires ffmpeg to be installed. The `@ffmpeg-installer/ffmpeg` package should install it automatically, but if codecs aren't working:

1. Check server console for ffmpeg errors
2. Verify ffmpeg is installed: `ffmpeg -version`
3. If needed, install ffmpeg manually:
   - Windows: Download from https://ffmpeg.org/download.html
   - Linux: `sudo apt install ffmpeg`
   - macOS: `brew install ffmpeg`

### Poor network quality despite good connection

- Check if other applications are using bandwidth
- Try switching to a different codec
- Reduce quality and FPS settings manually
- Check server CPU usage (high CPU can cause latency)

### Adaptive quality too aggressive

Edit `config.js` on the server:

```javascript
compression: {
  adaptive: {
    enabled: false,  // Disable adaptive streaming
  }
}
```

Or adjust thresholds:

```javascript
performance: {
  networkMonitoring: {
    latencyThreshold: {
      good: 100,   // More lenient thresholds
      fair: 250,
      poor: 500
    }
  }
}
```

## Technical Details

### Adaptive Algorithm

The server monitors network latency by tracking frame delivery times:

1. Collects last 30 latency samples
2. Calculates average latency
3. Determines quality tier (excellent/good/fair/poor)
4. Adjusts quality and FPS accordingly
5. Re-evaluates every 10 frames

### Network Quality Calculation

```javascript
if (avgLatency < 50ms) → excellent → quality +5%, FPS +1
if (avgLatency < 150ms) → good → no change
if (avgLatency < 300ms) → fair → quality -10%, FPS -2
if (avgLatency > 300ms) → poor → quality -20%, FPS -2
```

## Future Enhancements

Potential improvements for future versions:

- [ ] WebRTC-based streaming for peer-to-peer connections
- [ ] Hardware-accelerated encoding on server
- [ ] Delta frame compression (only send changed regions)
- [ ] Audio streaming support
- [ ] Multi-monitor switching without reconnection
- [ ] Bandwidth usage statistics
- [ ] Connection quality history graph

## Credits

Features inspired by [RustDesk](https://github.com/rustdesk/rustdesk), an open-source remote desktop software.
