# traefik：主機共用 HTTPS 入口（安裝設定）

> 何時讀：要安裝、設定、維運或排查本服務時。要把自己的服務接上本入口，讀 [USAGE.md](USAGE.md)（即說明頁 `https://traefik.lan.example.com` 的內容）。要知道為何這樣設計、改規則的影響與風險，讀 [docs/traefik/README.md](../../docs/traefik/README.md)。

本目錄已備齊所有部署檔（`compose.yaml`、`guide/` 說明頁、`.env.example`、說明頁內容 `USAGE.md`），安裝只需在本機填設定檔、同步到主機、啟動，不必改檔。

## Port

| Port | 協定 | 對外 | 用途 |
|---|---|---|---|
| 443（`TRAEFIK_PUBLIC_PORT`；主機 443 被佔用時改用其他 port，網址須帶 `:port`；前面另有代理把 443 轉進來時以 `TRAEFIK_URL_PORT` 指定網址的 port） | TCP | ✅ 路由器轉送到 .21 | 所有接入服務與說明頁的 HTTPS |
| 80（`TRAEFIK_HTTP_PORT`；留空時只綁 loopback） | TCP | ❌ | 內網 HTTP，不跳轉 HTTPS，接入方須另設 router |

## 1. Cloudflare DNS（一次性）

在根網域所在的 zone 新增下列記錄，Proxy status 皆設 **DNS only**（不經 Cloudflare 代理）：

| 用途 | 類型 | 名稱 | 內容 |
|---|---|---|---|
| 對外（`TRAEFIK_BASE_DOMAIN`） | CNAME | `wan`、`*.wan` | `myhost.ddns.net`（DDNS，跟著公網 IP） |
| 內網（`TRAEFIK_LAN_DOMAIN`） | A | `lan`、`*.lan` | `192.168.1.21` |

## 2. Cloudflare API token

Traefik 用它在 Cloudflare 建立憑證驗證用的 TXT 記錄。建立路徑：Cloudflare Dashboard → 右上頭像 → My Profile → API Tokens → Create Token → Custom token：

- Permissions：`Zone`／`Zone`／`Read`、`Zone`／`DNS`／`Edit`（缺 Read 會 403）
- Zone Resources：`Include`／`Specific zone`／根網域所在的 zone
- 選填：Client IP Address Filtering 限 .21 公網 IP（IP 變動時 token 失效）

token 建立後只顯示一次，第 4 步填入設定檔。

## 3. Let's Encrypt

免事先註冊：首次簽發時 Traefik 以 `.env` 的 `ACME_EMAIL` 自動建立 ACME 帳號並同意服務條款，帳號金鑰與憑證存於 volume `letsencrypt` 的 `acme.json`。email 只作帳號聯絡（Let's Encrypt 已不寄到期通知），續期由 Traefik 自動處理。

## 4. 建立設定檔並同步到主機

在本機以範本建立該主機的設定檔 `.env.<主機名>`（不進版控），填入 `ACME_EMAIL`、`CF_DNS_API_TOKEN` 與根網域（只支援內網的主機，對外網域留空），各變數說明見 `.env.example`；再於 repo 根目錄用 `tools/install.sh` 把本目錄同步到主機 `~/traefik/`，設定檔一併存成主機的 `.env`（只同步、不啟動；選檔順序與 `-p <profile>` 見 `tools/install.sh -h`）：

```bash
# 本機以範本建立 minipc-01 的設定檔並填值（不進版控）
cp services/traefik/.env.example services/traefik/.env.minipc-01 && vi services/traefik/.env.minipc-01
# 同步部署檔到主機 ~/traefik/，設定檔存成主機的 .env（只同步、不啟動）
tools/install.sh traefik minipc-01
```

## 5. 啟動

本服務須先於所有接入方啟動（由它建立共用網路 `traefik-proxy`）。回到 repo 根目錄啟動全部容器（traefik 與說明頁 guide）：

```bash
tools/run.sh up traefik minipc-01
```

## 6. 驗證憑證

啟動後約 1–2 分鐘簽好。依 [USAGE.md〈驗證憑證〉](USAGE.md#驗證憑證) 的指令查 `traefik.lan.example.com`（指令中的 `:443` 換成 `TRAEFIK_PUBLIC_PORT`）；顯示 `TRAEFIK DEFAULT CERT` 表示尚未簽好，看 log 找原因。

## 常用操作

啟停與狀態用 `tools/run.sh [up|down|start|stop|restart|list] <服務> minipc-01`（省略指令即列狀態）；其餘在主機 `~/traefik/` 執行：

| 目的 | 指令 |
|---|---|
| 改設定後套用 | 本機改 `.env.<主機名>` 並 `tools/install.sh` 同步，再 `docker compose up -d --force-recreate traefik`（只改 configs 內容時不會自動重建） |
| 改 `USAGE.md`，或改根網域／port 後更新說明頁 | 先 `tools/install.sh` 同步，再 `docker compose up -d --build guide`（建置時把文件中的示例網域與 port 換成 `.env` 的值） |
| 看 log | `docker compose logs -f traefik` |

停止、重建或回復前讀 docs/traefik §5（會中斷所有接入方）；`down` 不加 `-v` 以保留憑證。

## 讓其他服務使用

要把其他 compose project 接上本入口時讀 [USAGE.md](USAGE.md)，裡面有網址規則、compose 範例、驗證憑證指令與接入契約。說明頁顯示的就是這份文件，改了接入規則要同步更新它，並依〈常用操作〉重建 guide。
