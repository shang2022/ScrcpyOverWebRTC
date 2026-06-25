# Scrcpy over WebRTC (CloudPhone)

中文 | [English](README.en.md)

基于 WebRTC 和 Scrcpy 的高性能、低延迟云手机解决方案，无需客户端，可以通过网页直接连接。
采用 **Fat Agent (直连模式)** 架构，结合 **硬件级 PTS 透传** 技术，实现媲美原生 Scrcpy 的丝滑体验。

<p align="center">
  <img src="screenshot/screenshot-pc.png" width="70%" />
  <img src="screenshot/screenshot-phone.jpg" width="20%" />
</p>

## 1. 核心特性

- **极致流畅**: 采用零扫描流解析 (Zero-Search Parsing)，不引入新的内存拷贝，性能和原生scrcpy基本一致。
- **公网增强**: 原生支持 IPv6 直连，彻底绕过运营商 CGNAT 封锁，显著提升移动网络下的打洞成功率。
- **全能交互**: 支持多指触控、物理按键模拟、自定义映射（键盘按键映射到屏幕）、WebADB 终端、实时高频快照。
- **动态控制**: 支持在连接前或连接后通过 UI 面板动态修改设备分辨率、码率、帧率以及开启/关闭 BWE 动态码率。
- **一键部署**: 支持 WebUSB/WebADB 浏览器直连物理设备部署，无需本地安装 ADB 环境。
- **网页直连**: 支持所有终端（IOS/Android/Win/Mac/Linux）通过浏览器连接。
- **支持群控**: 支持高同步率群控, 从控机器支持高帧率预览。
- **摆脱ADB**: 支持以root权限运行

## 2. 快速开始
```bash
  docker pull buutuu/scrcpy-over-webrtc:latest
```

### 2.1 Host 网络模式 (推荐)
如果您的 Linux 宿主机有独立的公网 IP 或是纯内网环境，且没有端口占用冲突，**首选 Host 模式**。

*   **启动命令**:
    ```bash
    docker run -d \
      --name cp-aio \
      --net=host \
      -e PUBLIC_IP=<宿主机真实IP> \
      buutuu/scrcpy-over-webrtc:latest
    ```
*   **优势**: 容器直接使用宿主机网络，零 NAT 转发损耗，无需映射大量 UDP 端口段，网络吞吐量最高。
*   **注意**: 必须确保宿主机上 `3478`（TURN）和 `8443`（信令）等端口未被其他服务占用。
*   **PUBLIC_IP**: 当有公网IP时填入公网IP，当局域网内使用内填入宿主机IP

---

### 2.2 NAT / Bridge 网络模式 (常规)
如果运行在 macOS、Windows 等 Docker 虚拟化环境，或者出于安全考量必须使用 `-p` 映射端口，请务必遵循以下两条策略，**切忌映射整个 `49152-65535` 端口段（会导致宿主机 OOM 崩溃）**。

#### 策略 A：收窄 TURN UDP 端口段映射
在配置中指定一个极窄的中转 UDP 端口区间（如 100 个），并只放行此范围。

*   **启动命令 (常规对称映射)**:
    ```bash
    docker run -d --name cp-aio \
      -p 8443:8443 \
      -p 3478:3478/tcp \
      -p 3478:3478/udp \
      -p 55000-55100:55000-55100/udp \
      -e PUBLIC_IP=<宿主机物理IP> \
      -e COTURN_MIN_PORT=55000 \
      -e COTURN_MAX_PORT=55100 \
      buutuu/scrcpy-over-webrtc:latest
    ```

#### 策略 B：非对称端口映射（重点）
当宿主机的默认端口（如 8443、3478）被其他服务占用，导致您不得不将外部端口映射为非对称端口（如 8443 映射为 18443，3478 映射为 13478）时。

> [!WARNING]
> 如果直接启动，容器内部的信令服务由于不知道外部映射了什么端口，依然会将默认的 `3478` 作为 TURN 地址下发给前端。导致前端网页尝试连接 `宿主机:3478` 失败而黑屏。
> 
> **解决方案**：必须传入 `EXTERNAL_SIGNALING_PORT` 和 `EXTERNAL_TURN_PORT` 环境变量，明确告知容器外部映射的公开端口。

*   **启动命令 (非对称端口映射)**:
    ```bash
    docker run -d --name cp-aio \
      -p 18443:8443 \
      -p 13478:3478/tcp \
      -p 13478:3478/udp \
      -p 55000-55100:55000-55100/udp \
      -e PUBLIC_IP=192.168.100.242 \
      -e COTURN_MIN_PORT=55000 \
      -e COTURN_MAX_PORT=55100 \
      -e EXTERNAL_SIGNALING_PORT=18443 \
      -e EXTERNAL_TURN_PORT=13478 \
      buutuu/scrcpy-over-webrtc:latest
    ```

*   **PUBLIC_IP**: 当有公网IP时填入公网IP，当局域网内使用内填入宿主机IP

## 3. 添加机器

服务拉起后，一切连接入口都将通过容器日志清晰打印。

### 3.1 终端信息打印
运行以下命令查看终端的醒目接入说明：
```bash
docker logs cp-aio
```
日志在最后会输出由传入变量自动计算得到的接入指南：
```text
========================================================
          🎉 CloudPhone 容器服务已成功启动！
========================================================
 1. 网页管理后台连接 URL (请在浏览器中打开):
    https://192.168.100.242:18443

 2. Android 设备/容器 Agent 接入启动指令:
    ./cloudphone-agent \
      -signaling "wss://192.168.100.242:18443/register_agent" \
      -id "<您的设备ID>" \
      -ice-servers "turn:cloudphone_user:cloudphone_secure_password@192.168.100.242:13478?transport=udp,stun:192.168.100.242:13478"
========================================================
```

---

## 4. 手动网页部署与 adb 指导

我们在前端 Web 页面中集成了方便离线/手动调试的面板：

1.  **资源卡片下载**：网页右下角提供了可以直接下载对应平台 `Agent (ARM64/AMD64/ARMv7)` 以及配套 `scrcpy 核心库 (libsys_core.so)` 的一键下载卡片。
2.  **ADB 命令行一键生成**：页面会根据您当前的输入参数，动态拼接生成完备的手动 ADB 启动命令，并配以 `一键复制` 按钮，直接拷贝到终端运行即可，杜绝了多命令行参数拼接错误的烦恼。

## License

**MIT License** - 前端 `web-app` 目录源代码开源。

*注意：`agentd` 与 `bin` 目录下的代理和信令服务器二进制文件仅供学习和个人测试使用。*