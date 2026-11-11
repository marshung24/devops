# docker-registry：內網開發用 image 暫存區（安裝設定）

> 何時讀：要安裝、維運或排查本服務時。要推拉 image、查清單或看安全須知，讀 [USAGE.md](USAGE.md)（即說明頁 `https://registry.lan.example.com` 的內容）。要知道為何這樣設計、存取邊界與風險，讀 [docs/docker-registry/README.md](../../docs/docker-registry/README.md)。

`registry` 與說明頁 `guide` 共用一個網域，經主機共用 Traefik 提供 HTTPS：`/v2` 給 docker 用戶端，其餘路徑是說明頁（`https://<REGISTRY_DOMAIN>`，內容為 `USAGE.md` 加 image 清單）。只限 LAN 與 NetBird 來源；寫入（push、刪除）可選用帳密（`REGISTRY_AUTH_USERS`），未設時任何人可推、拉、刪；說明頁清單一律免登入；image 存於主機目錄 `REGISTRY_DATA_DIR`（不存在時自動建立）。

## 前提

- 本主機的 traefik 已啟動（它建立網路 `traefik-proxy`、提供 `*.<TRAEFIK_LAN_DOMAIN>` 憑證），見 [services/traefik/README.md](../traefik/README.md)。
- 使用端（push／pull 的機器）在 LAN 內或已連上 NetBird。

## 安裝與啟動

在本機以範本建立該主機的設定檔 `.env.<主機名>`（不進版控），填 `REGISTRY_DOMAIN`、`REGISTRY_PUBLIC_PORT`、`REGISTRY_DATA_DIR`，要擋寫入再填 `REGISTRY_AUTH_USERS`；再於 repo 根目錄同步到主機 `~/docker-registry/`（設定檔一併存成主機的 `.env`，只同步、不啟動），最後啟動：

```bash
# 本機以範本建立 minipc-01 的設定檔並填值（不進版控）
cp services/docker-registry/.env.example services/docker-registry/.env.minipc-01 && vi services/docker-registry/.env.minipc-01
# 同步部署檔到主機 ~/docker-registry/，設定檔存成主機的 .env（只同步、不啟動）
tools/install.sh docker-registry minipc-01
# 在主機啟動 registry 與說明頁（首次會建置說明頁、建立資料目錄）
tools/run.sh up docker-registry minipc-01
```

改設定時一樣改本機檔再跑 `tools/install.sh`，套用見〈常用操作〉。

驗證（在 LAN 內）：`curl https://registry.lan.example.com/v2/` 回 `{}`、瀏覽器開 `https://registry.lan.example.com` 看到說明頁與 image 清單；外網來源回 404。有設帳密時 `/v2/` 改回 401（帶 `-u <帳號>` 回 `{}`），未帶帳密 `curl -X POST https://registry.lan.example.com/v2/x/blobs/uploads/` 回 401、帶 `-u <帳號>` 回 202。

## 常用操作

在主機 `~/docker-registry/` 執行；啟停與狀態用 `tools/run.sh [up|down|start|stop|restart|list] docker-registry minipc-01`。

| 目的 | 指令 |
|---|---|
| 看容量 | `sudo du -sh <REGISTRY_DATA_DIR>`、`df -h <REGISTRY_DATA_DIR>` |
| 釋放已刪除 tag 的空間（GC） | `docker compose stop registry && docker compose run --rm registry garbage-collect --delete-untagged /etc/distribution/config.yml; docker compose start registry` |
| 整庫重置（刪除全部 image） | `docker compose stop registry && sudo rm -rf <REGISTRY_DATA_DIR>/docker && docker compose start registry` |
| 改 `.env.<主機名>` 或 `USAGE.md` 後套用 | 本機先 `tools/install.sh` 同步，再於主機 `docker compose up -d --build`（重建說明頁；資料目錄變更時一併重建 registry） |
| 增刪帳號、改密碼 | 本機產生 `htpasswd -nbB <帳號> <密碼>`，改 `.env.<主機名>` 的 `REGISTRY_AUTH_USERS`（多組逗號分隔、整串單引號），`tools/install.sh` 同步後於主機 `docker compose up -d registry` 重建容器套用 |
| 看 log | `docker compose logs -f registry` |

刪除 tag（說明頁或 API）只移除參照，同名 tag 重推後舊版也仍佔空間；GC 才實際釋放，執行期間 registry 停止、無法推拉，選沒人用的時段。GC 只清已無 tag 指向的內容，多平台 image 不受影響。
