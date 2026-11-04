# 讓其他服務使用本主機共用 Traefik（接入者）

> 何時讀：要讓自己的 compose project 經本入口對外提供 HTTPS 時。本文即說明頁 `https://traefik.lan.example.com`（`traefik.<TRAEFIK_LAN_DOMAIN>`，只限私有網段與 NetBird 來源）的內容。
> 前提：Traefik 已由維運者安裝並運作（安裝設定見同目錄 `README.md`）。你只需照下列方式修改**你自己的** `compose.yaml`，不必動 Traefik 的任何檔案。

## 適用範圍

本入口給走 HTTP 系協定的服務用：網站、REST API、gRPC、WebSocket。

MySQL、Redis、MQTT 等一般 TCP 服務與 UDP 服務不經本入口：它們無法靠網域共用 port，要開專用 entrypoint，好處也有限。同機應用直接走 Docker 網路，跨機才開 port。

## 網址

每個服務取一個名稱，本主機的根網域各用一次；DNS 與萬用字元憑證都已涵蓋，不必再設。只涵蓋下一層，`a.b.wan.example.com` 不行。

| 用途 | 網址 |
|---|---|
| 外網 | `https://<名稱>.wan.example.com` |
| LAN 內 | `https://<名稱>.lan.example.com` |

## compose 範例

以下以 project `myproj` 的服務 `myapp`（容器內聽 8080）為例。要點：接上外部網路 `traefik-proxy`、加 `traefik.enable=true`；router 列出本主機所有根網域、走 `websecure`、開 TLS；主機不必 publish port。

```yaml
services:
  myapp:
    image: ...
    networks: [proxy]
    labels:
      - traefik.enable=true
      - traefik.http.routers.myproj-web.rule=Host(`myapp.wan.example.com`) || Host(`myapp.lan.example.com`)
      - traefik.http.routers.myproj-web.entrypoints=websecure
      - traefik.http.routers.myproj-web.tls=true
      - traefik.http.services.myproj-web.loadbalancer.server.port=8080

networks:
  proxy:
    name: traefik-proxy
    external: true
```

改完在你的 project 目錄執行 `docker compose up -d`，再依下節確認憑證。

## 驗證憑證

在 LAN 內用下列指令直連本主機查看憑證，`<網域>` 換成要查的名稱（如 `myapp.lan.example.com`）：

```bash
openssl s_client -connect lan.example.com:443 -servername <網域> </dev/null 2>/dev/null | openssl x509 -noout -issuer -ext subjectAltName
```

簽發者為 Let's Encrypt、SAN 含本主機根網域與其 `*.` 即成功；顯示 `TRAEFIK DEFAULT CERT` 表示憑證尚未簽好或網域不在涵蓋範圍，請洽維運者。

## 規則（接入契約，變更須同步所有接入方）

| 項目 | 規定 |
|---|---|
| 網路 | 接 `traefik-proxy`（172.30.0.0/24）；🚫 不得佔用 `172.30.0.10`（Traefik） |
| entrypoint | 一律寫 `entrypoints=websecure` |
| 網域 | rule 列出本主機所有根網域；漏列的網域連不到 |
| 憑證 | `tls=true`，自動取用萬用字元憑證；根網域外的名稱改用 `tls.certresolver=le` 單獨申請（該網域須在 token 可管理的 zone 內並自行設 DNS） |
| 命名 | router／service／middleware 以 `<project>-` 開頭；名稱整台共用，重名會被略過 |
| 信任代理標頭 | 後端要讀 `X-Forwarded-*` 時，trusted proxy 設 `172.30.0.10/32` |
