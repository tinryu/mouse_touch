# Mouse Touch (mouse_track)

A powerful Flutter-based remote mouse and keyboard controller that allows you to control your PC from your mobile device with absolute precision.

## 🚀 Features

- **Absolute Positioning**: Touch anywhere on your mobile screen, and the cursor jumps directly to that position on your PC (Chrome Remote Desktop style).
- **Direct Manipulation**: Drag your finger to move the cursor smoothly in real-time.
- **Gesture Support**:
  - **Single Tap**: Left-click at the current position.
  - **Long Press**: Right-click at the current position.
  - **Two-Finger Scroll**: Natural scrolling support.
  - **Two-Finger Zoom**: Zoom in/out on the remote screen view.
- **High Performance**: Throttled at 60 FPS (16ms) to ensure smooth performance without flooding the server.
- **Smart Discovery**: Uses UDP to automatically find and connect to the remote server on your local network.
- **Visual Feedback**: Real-time cursor indicator shows exactly where you're touching.
- **Dark Mode**: Sleek Material 3 dark theme by default.
- **Tutorial System**: Built-in onboarding to help you master the controls.

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart)
- **Communication**: WebSockets (Real-time control), UDP (Auto-discovery)
- **Design**: Material 3 Design System

## 🏗️ Architecture

The project consists of two main parts:
1. **Client (this project)**: A Flutter application that captures touch gestures and sends them to the server.
2. **Server**: A lightweight Node.js/Node-Robot server that executes the commands on the host PC.

## 🏁 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- A running instance of the `remote_server_mouse` (Node.js) on your host PC.

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/tinryu/mouse_touch.git
   cd mouse_touch/mouse_track
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## 🖱️ Mouse Control Guide

| Action | Gesture |
|--------|---------|
| **Move Cursor** | 1-finger drag (Absolute positioning) |
| **Left Click** | Single tap |
| **Right Click** | Long press |
| **Scroll** | 2-finger drag (vertical) |
| **Zoom View** | Pinch gesture |

## 📦 Project Structure

- `lib/screens/`: Contains the main UI screens (`HomeScreen`, `MouseControlScreen`, `ScreenRemoteScreen`).
- `lib/utils/`: Utility classes for networking and discovery.
- `assets/`: App icons and images.

---

Developed with ❤️ using Flutter.
