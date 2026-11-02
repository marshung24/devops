# devops
各式維運工具

## 目錄

- `docs/<主題>/`：設計規格——要了解為何這樣做、選案、風險與上線／回復程序時讀。
- `services/<服務>/`：可部署的服務（compose、映像、`.env.example`）——要部署、調參數或排查時讀其 README。

## 索引

| 主題 | 設計 | 服務 | 摘要 |
|---|---|---|---|
| traefik | [docs/traefik](docs/traefik/README.md) | [services/traefik](services/traefik/README.md) | minipc-01 共用 HTTPS 入口：各 project 經外部網路 `traefik-proxy` 接入，Let's Encrypt（Cloudflare DNS-01），對外 8443；說明頁 `https://traefik.<TRAEFIK_LAN_DOMAIN>:8443`（限 LAN／NetBird／路由器 VPN） |
