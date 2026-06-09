# Scrcpy over WebRTC (CloudPhone)

[中文](README.md) | English

A high-performance, low-latency cloud phone/cloud desktop solution based on WebRTC and Scrcpy. No client required; you can connect directly through a web browser.
It adopts a **Fat Agent (Direct Connection)** architecture, combined with **Hardware-level PTS Passthrough** technology, to achieve a silky-smooth experience comparable to native Scrcpy.

<p align="center">
  <img src="screenshot/screenshot-pc.png" width="70%" />
  <img src="screenshot/screenshot-phone.jpg" width="28%" />
</p>

## Core Features

- **Ultimate Smoothness**: Utilizes Zero-Search Parsing, avoiding any new memory copies. Performance is practically identical to native scrcpy.
- **Versatile Interaction**: Supports multi-touch, physical key simulation, custom key mapping (mapping keyboard keys to screen actions), WebADB terminal, and real-time snapshots.
- **Dynamic Control**: Dynamically modify device resolution, bitrate, framerate, and toggle BWE (Bandwidth Estimation) dynamic bitrate from the UI panel, either before or after connecting.
- **One-Click Deployment**: Supports deploying the Agent directly to physical devices via browser using WebUSB/WebADB. No local ADB environment required.
- **Direct Web Access**: Supports connection from any OS (iOS/Android/Windows/Mac/Linux) simply via a web browser.
- **ADB Freedom**: Once deployed, you no longer need wired or wireless ADB connections to the device. The system supports tunneling ADB directly into the web browser for immediate use.

## Quick Start

### 1. Start the Server

```bash
# Default start
./start_server.sh
```
*Windows users: Please go to the `bin/` directory and run `run.bat`*

After starting, access it in your browser: `http://localhost:8443`

### 2. Deploy Agent to Android

```bash
cd agentd
./run.sh -id my-phone -signaling ws://<Server-IP>:8443
```

#### 3. Run entirely locally on Android (Computer-free)
You can push the full suite including the signaling server directly to your phone, making the phone its own server:
1. Push the Android standalone package and static assets:
   ```bash
   adb push android /data/local/tmp/
   adb push assets /data/local/tmp/android/
   ```
2. Start services on your phone:
   ```bash
   adb shell sh /data/local/tmp/android/setup.sh
   ```

#### 4. Docker / Redroid Container
When the Agent is running inside an isolated container, you need to specify the host IP and expose the UDP port in your Docker run command (e.g., `-p 50000:50000/udp`):
```bash
./run.sh -id redroid-01 \
  -signaling ws://<Server-IP>:8443 \
  -external-addr "<Host-IP>" \
  -webrtc-port 50000
```

## Directory Structure

```text
ScrcpyOverWebRTC/
├── web-app/              # Frontend source code
├── bin/                  # Signaling server
│   ├── linux_amd64/
│   ├── linux_arm64/
│   ├── darwin_amd64/
│   ├── darwin_arm64/
│   ├── windows_amd64/
│   └── windows_arm64/
├── agentd/               # Android Agent
│   ├── cloudphone-agent-arm64
│   ├── cloudphone-agent-amd64
│   ├── scrcpy-server.jar
│   └── run.sh
├── android/              # Android Standalone Package (Run entirely on Android)
│   ├── webrtc-signaling
│   ├── cloudphone-agent
│   ├── scrcpy-server.jar
│   └── setup.sh
├── start_server.sh      # Startup script
├── build.sh             # macOS / Linux compile & package script
├── build.bat            # Windows compile & package script
└── README.md
```

## Frontend Development (web-app)

The frontend code is fully open-source. You are free to modify the UI, adjust interactions, or perform secondary development.

> [!IMPORTANT]
> **Prerequisites**: Local development and building require [Node.js](https://nodejs.org/) (recommended v18 or higher) to be installed beforehand.

### Quick Build
- **macOS / Linux**:
  ```bash
  ./build.sh
  ```
- **Windows**:
  Double-click `build.bat` or run in terminal:
  ```cmd
  build.bat
  ```

### Tech Stack
- Vue 3 + Composition API
- Vite Build Tool
- Pinia State Management
- WebRTC Data & Video Stream Communication

### Local Development & Debugging
```bash
cd web-app
npm install
npm run dev
```

### Features
- **Web-Based Device Matrix**: Real-time display of online devices and screen snapshots.
- **Low-Latency Control**: WebRTC video streaming + custom protocol touch/key mapping.
- **Custom Keymapping Engine**: Supports various custom mappings including tapping, swiping, virtual joystick, and commands.
- **WebADB Console**: Built-in terminal based on `xterm.js` with native ADB tunneling for driverless cloud debugging.
- **Dynamic Parameter Settings**: Configure bitrate, max resolution, framerate, BWE dynamic bandwidth, and log levels directly from the UI before connecting.

## Agent Deployment Parameters

```bash
./run.sh -id <Device-ID> -signaling ws://<Server-IP>:8443 [options]
```

| Parameter | Description | Default |
|------|------|--------|
| `-id` | Unique device identifier | Required |
| `-signaling` | Signaling server address | Required |
| `-external-addr` | Manually specify host or public IP | Auto-detect |
| `-webrtc-port` | Fixed port bound for WebRTC communication | 50000 |
| `-bitrate` | Video bitrate (bps) | 4000000 |
| `-max-fps` | Maximum framerate | No limit |
| `-max-size` | Video maximum edge length | No limit |
| `-bwe` | Enable WebRTC Bandwidth Estimation (TWCC) & dynamic bitrate | true |
| `-snapshot-interval`| Dashboard snapshot update interval (seconds) | 10 |
| `-root` | Force run service with Root privileges | false |

## Protocol Specification (For Third-Party Integration)

The underlying protocol information exposed by the frontend, convenient for integrating your own client systems:

### Signaling Protocol (WebSocket)
- Endpoint: `/connect_client`
- Supported message types: `offer`, `answer`, `ice_candidate`, `device_list`, `device_quit`

### WebRTC DataChannel
Once the WebRTC connection is established, the Agent opens two key out-of-band data channels (DataChannel):
- `input-channel`: Used for sending touch and key commands.
- `adb-channel`: ADB raw stream tunnel.

#### Touch Control Protocol Example
The frontend sends a JSON string via the `input-channel`:
```json
{"type":"touch", "id":0, "action":0, "x":100, "y":200, "w":1080, "h":1920}
```
- `action`: `0`=DOWN, `1`=UP, `2`=MOVE
- `id`: Finger tracking ID (0-9 for touch, -1 for mouse)
- `x`/`y`: Coordinates
- `w`/`h`: Reference screen width and height (The Agent automatically recalculates the mapping ratio based on the device's actual resolution)

## License

**MIT License** - Frontend `web-app` directory source code is open source.

*Note: The proxy and signaling server binaries under the `agentd` and `bin` directories are for learning and personal testing use only.*