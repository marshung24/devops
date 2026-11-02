# devops
各式維運工具

## 目錄

- `docs/<主題>/`：設計規格——要了解為何這樣做、選案、風險與上線／回復程序時讀。
- `services/<服務>/`：可部署的服務（compose、映像、`.env.example`）——要部署、調參數或排查時讀其 README。README 會隨服務安裝到主機，`tools/install.sh` 安裝時自動在標題下加註作者（該檔第一次 commit 者）與最後更新（最後一次 commit 者與日期），原檔不必手寫。
- `tools/install.sh [-n] <服務> <ssh 主機>`：把 `services/<服務>/` 同步到主機 `~/<服務>/`（不啟動；刪除主機多餘檔案，`.env` 本機有才覆蓋、沒有就保留主機那份；`-n` 只列變動）。
- `tools/run.sh [up|down|start|stop|restart|list] <服務> <ssh 主機> [compose 服務...]`：在主機 `~/<服務>/` 執行對應的 `docker compose` 指令（`up` 帶 `-d`）；省略指令或 `list` 列出該服務的容器與狀態。

## 索引

| 主題 | 設計 | 服務 | 摘要 |
|---|---|---|---|
| traefik | [docs/traefik](docs/traefik/README.md) | [services/traefik](services/traefik/README.md) | minipc-01 共用 HTTPS 入口：各 project 經外部網路 `traefik-proxy` 接入，Let's Encrypt（Cloudflare DNS-01），對外 8443；說明頁 `https://traefik.<TRAEFIK_LAN_DOMAIN>:8443`（限 LAN／NetBird／路由器 VPN） |
