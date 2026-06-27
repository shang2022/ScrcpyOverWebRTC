# ScrcpyOverWebRTC 前端二次开发指南

本项目采用前后端解耦架构：
*   **前端控制台 (`web-app`)**: 基于 Vue3 + Vite 编写的管理后台仪表盘与部署页面。
*   **后端信令与媒体服务 (`webrtc-signaling`)**: 基于 Go 编写的信令服务器，并整合了 `coturn` 中转。

由于开源仓库不再直接提供各平台编译的后端二进制包，二次开发推荐采用 **“本地前端 + 官方 Docker AIO 容器后端”** 的混合开发模式，完全不需要本地编译 Go/C++。

---

## 1. 准备后端服务 (基于 Docker 容器)

直接在开发机（或局域网内的某台 Linux 主机）上运行官方打包的一体化 AIO 容器。

```bash
docker run -d --name cp-dev-backend \
  -p 8443:8443 \
  -p 3478:3478/tcp \
  -p 3478:3478/udp \
  -p 50000-50100:50000-50100/udp \
  -e PUBLIC_IP=<您的开发机/容器宿主机IP> \
  -e COTURN_MIN_PORT=50000 \
  -e COTURN_MAX_PORT=50100 \
  buutuu/scrcpy-over-webrtc:latest
```
*(注：如果是在本地单机开发，`PUBLIC_IP` 可设为 `127.0.0.1`)*

---

## 2. 本地前端二次开发与实时热更新

在前端源码目录运行开发服务器。Vite 的代理会将所有的 API 和 WebSocket 连接自动转发给您指定的后端容器。

1.  **进入前端目录并安装依赖**:
    ```bash
    cd web-app
    npm install
    ```

2.  **启动开发服务器**:
    通过环境变量 `VITE_PROXY_TARGET` 动态指定后端的 IP 地址与信令端口：
    ```bash
    # 如果后端跑在本地
    VITE_PROXY_TARGET=http://localhost:8443 npm run dev
    
    # 如果后端跑在局域网其他机器 (例如 192.168.1.100)
    VITE_PROXY_TARGET=http://192.168.1.100:8443 npm run dev
    ```

3.  **打开浏览器**:
    访问 `http://localhost:3000` 即可实时热更新开发。此时修改任何 Vue 代码，浏览器都会瞬间完成刷新并保持连接状态。

---

## 3. 本地打包与容器挂载测试

当二次开发前端代码编写完毕后，您可以将其打包，并通过卷挂载（Volume Mount）在生产级的 Docker 环境中进行功能验证。

1.  **前端打包**:
    > [!IMPORTANT]
    > 在首次打包前，必须确保您已经安装了依赖，否则由于没有本地安装 Vite 编译器会报错 `sh: vite: command not found`。
    
    在 `web-app` 目录下执行：
    ```bash
    # 安装全部前端依赖 (如已安装可跳过)
    npm install
    
    # 编译前端
    npm run build
    ```
    打包产物默认输出至项目根目录的 `assets/` 目录下。

2.  **挂载至官方容器中运行**:
    启动容器时，使用 `-v` 参数将本地编译出的静态网页资源目录直接挂载到容器内的 `/app/assets` 中：
    ```bash
    docker run -d --name cp-dev-test \
      -p 8443:8443 \
      -p 3478:3478/tcp \
      -p 3478:3478/udp \
      -p 50000-50100:50000-50100/udp \
      -e PUBLIC_IP=<宿主机IP> \
      -v /absolute/path/to/ScrcpyOverWebRTC/assets:/app/assets \
      buutuu/scrcpy-over-webrtc:latest
    ```

### 💡 自动补全机制 (二次开发防覆盖)
通常，您本地打包的前端 `assets/` 目录中是**没有** `agent/` 目录及里面各种庞大的 Agent 物理二进制的。
直接挂载到 `/app/assets` 会导致原本内置在容器里的 Agent 下载资源（例如 `agent-deploy.zip`）被挂载行为直接覆盖，进而导致网页上下载 Agent 报错 404。

**我们已在 `entrypoint.sh` 中集成了自动补全嫁接逻辑**：
当容器启动时，若检测到 `/app/assets/agent` 不存在，它会自动建立指向容器内部安全备份区 `/app/agent_binaries` 的符号链接（软链接），**瞬间恢复 `/agent/agent-deploy.zip` 等包的下载能力**，确保二次开发的前端开箱即用。
