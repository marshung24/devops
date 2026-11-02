# vpn-router

> 何時讀：要部署、調整參數、設 Dashboard、建使用者帳號或排查本服務時。要知道目標、選案理由、路由與權限契約、上線驗收與風險，讀 [docs/vpn-router/README.md](../../docs/vpn-router/README.md)。使用者端的申請與連線方式見 [USAGE.md](USAGE.md)（即使用者說明頁）。

本服務部署在 LAN 內一台**轉送主機**上，讓 LAN（經 DHCP）與遠端（經 NetBird）前往目標網段的流量經它轉送。下文的主機名、IP 與網段皆以 minipc-01（192.168.1.21）、目標網段 10.10.0.0/16、LAN 192.168.1.0/24 為例。

## 依賴

本服務的控制面與說明頁經主機上的共用反向代理對外，例：共用 Traefik（[services/traefik](../traefik/README.md)），須先安裝並運作：

| 依賴項目 | 本服務如何使用 | 反向代理未運作時 |
|---|---|---|
| 共用網路 `traefik-proxy` | dashboard、netbird-server、guide 接入此網路 | 建立容器失敗（找不到外部網路） |
| 對外 HTTPS entrypoint `websecure`（port 見 `TRAEFIK_PUBLIC_PORT`） | Dashboard、API、gRPC、Relay、說明頁都經它轉入 | 遠端 client 無法註冊或連線，Dashboard 與說明頁打不開 |
| 萬用字元憑證 | `NB_DOMAIN`、`VPN_GUIDE_DOMAIN` 須在其涵蓋的根網域下一層，router 只設 `tls=true` | 憑證不符，client 拒絕連線 |
| 反向代理固定 IP `172.30.0.10` | netbird-server 只信任此 IP 帶的 `X-Forwarded-*` | IP 變動時來源資訊失真 |

接入設定已寫在本目錄 `compose.yaml`，不必另改。`NB_PUBLIC_PORT` 須與反向代理的對外 port 相同。dhcp 與 netbird（routing peer）用 host network，不依賴反向代理。

## 容器

| 服務 | 用途 | 網路 |
|---|---|---|
| `dhcp` | dnsmasq，LAN DHCP，下發 `DHCP_ROUTE_NET` 分流路由 | host |
| `netbird` | NetBird client，routing peer，轉送 Dashboard 設定的網段給遠端 | host |
| `dashboard` | NetBird 管理介面 | `traefik-proxy` |
| `netbird-server` | Management＋Signal＋Relay＋STUN＋內建 IdP | 同上 |
| `guide` | 使用者說明頁 `https://<VPN_GUIDE_DOMAIN>`，渲染 `USAGE.md`，只限 `VPN_GUIDE_ALLOW` 來源 | 同上 |

## Port

| Port | 協定 | 服務 | 對外 | 用途 |
|---|---|---|---|---|
| `NB_PUBLIC_PORT`（預設 443，須同反向代理對外 port） | TCP | 共用反向代理 | ✅ 路由器轉送到轉送主機 | Dashboard、REST API、gRPC（Management／Signal）、Relay |
| `NB_STUN_PORT`（預設 3478） | UDP | netbird-server | ✅ 路由器轉送到轉送主機 | STUN，NAT 穿透，不可經代理 |
| 67 | UDP | dhcp | ❌ 只在 `DHCP_INTERFACE` | DHCP server |
| 51820 | UDP | netbird | ❌ 不需轉送 | WireGuard，NetBird 自動打洞，失敗時經 Relay |

## 使用方式

本目錄已備齊所有部署檔（`compose.yaml`、`dnsmasq/`、`guide/`、`USAGE.md`、`.env.example`），安裝只需同步到主機、填 `.env`、依序啟動，不必改檔。`tools/` 指令在 repo 根目錄執行，`<主機>` 填 ssh 主機名（例：minipc-01）；`docker compose` 指令在主機 `~/vpn-router/` 執行。

### 1. 前置

- 轉送主機已具備往目標網段的路由與轉送（見 docs §2）。
- 路由器：轉送 `NB_PUBLIC_PORT`/tcp、`NB_STUN_PORT`/udp → 轉送主機。
- 共用反向代理已上線（見〈依賴〉）；尚未部署時先依 [services/traefik](../traefik/README.md) 安裝。

### 2. 同步到主機並建立 `.env`

用 `tools/install.sh` 把本目錄同步到主機 `~/vpn-router/`（只同步、不啟動；本機沒有 `.env` 時保留主機那份，本機有則覆蓋）：

```bash
tools/install.sh vpn-router <主機>
```

到主機以範本建立 `.env`，依下表填值；預設值與三把金鑰的產生指令寫在 `.env.example` 註解：

```bash
ssh <主機>
cd ~/vpn-router && cp .env.example .env && vi .env
```

| 變數 | 說明 |
|---|---|
| `HOST_LAN_IP` | 轉送主機的 LAN IP：分流路由下一跳、routing peer 連控制面的位址（例：192.168.1.21） |
| `DHCP_INTERFACE` | DHCP 服務的 LAN 介面（例：enp2s0） |
| `DHCP_POOL_START`／`DHCP_POOL_END` | 位址池，不可涵蓋閘道與固定 IP 的主機（例：本案避開 .1、.21–.26） |
| `DHCP_LEASE_TIME` | 租期 |
| `DHCP_GATEWAY` | 預設閘道（原路由器） |
| `DHCP_DNS` | DNS，逗號分隔 |
| `DHCP_ROUTE_NET` | 目標網段，DHCP 把它指向轉送主機 |
| `NB_DOMAIN` | 控制面網域，須在反向代理對外根網域下一層 |
| `NB_PUBLIC_PORT` | 控制面對外 HTTPS port，須與反向代理相同 |
| `NB_STUN_PORT` | STUN port |
| `NB_PEER_HOSTNAME` | routing peer 在 NetBird 的名稱 |
| `NB_SETUP_KEY` | routing peer 註冊用一次性 key（控制面起來後才有） |
| `NB_AUTH_SECRET` | Relay 驗證密鑰 |
| `NB_SESSION_COOKIE_KEY`／`NB_STORE_ENCRYPTION_KEY` | Cookie／資料庫加密金鑰 |
| `VPN_GUIDE_DOMAIN` | 使用者說明頁網域，須在反向代理的 LAN 根網域下一層 |
| `VPN_GUIDE_ALLOW` | 說明頁允許的來源網段，逗號分隔（LAN、NetBird 100.64.0.0/10 及其他內部來源） |

DHCP 保留位址不走 `.env`：在 `compose.yaml` 的 `configs.dnsmasq` 加 `dhcp-host=<MAC>,<IP>`。

⚠️ `NB_STORE_ENCRYPTION_KEY` 建立後不可更換，否則既有資料無法解密；`.env` 要備份。

### 3. 啟動控制面

只啟動控制面兩個容器（Dashboard 與 netbird-server），routing peer 與 DHCP 先不動：

```bash
tools/run.sh up vpn-router <主機> dashboard netbird-server
```

接著用外網（例：手機 4G）開 `https://netbird.wan.example.com`（`NB_DOMAIN`；port 非 443 時網址要帶 port），首次會導到 `/setup` 建立 owner 帳號。owner 擁有管理使用者、路由與權限的全部權限，密碼請妥善保存。

### 4. 啟動 routing peer

在 Dashboard → Setup Keys 建一次性 key，填入主機 `.env` 的 `NB_SETUP_KEY`，再啟動 routing peer（它以這把 key 向控制面註冊為 `NB_PEER_HOSTNAME`）：

```bash
tools/run.sh up vpn-router <主機> netbird
```

### 5. Dashboard 路由與權限

要經 NetBird 轉送哪些網段在 Dashboard 設定，不在 `.env`；網段清單與權限契約讀 docs §4〈NetBird 路由與權限〉。以 owner 登入 Dashboard 依序設定：

1. **建 Network**：左側 Network Routing（Networks 頁）→ Add Network，取名（例：`office`）。
2. **加網段**：在該 Network 按 Add Resource，類型選 IP 網段（CIDR），每個要轉送的網段一筆（例：`10.10.0.0/16`、`192.168.1.0/24`）。
3. **指定轉送主機**：在同一 Network 按 Add Routing Peer，選 `NB_PEER_HOSTNAME` 對應的 peer，開 Masquerade（目的端沒有回 NetBird 網段的路由，回程靠它）。同一 Network 的網段都由這台轉送；要由別台轉送的網段另建 Network。
4. **設權限**：Access Control → Add Policy，來源群組 `Remote-Users`、目的選上述 resource；刪除預設的 `Default`（全互通）policy。
5. **確認**：routing peer 上 `docker compose exec netbird netbird status` 的 `Networks` 列出所有網段。

之後增減網段只要在同一 Network 加刪 resource，設定會即時推送，不必重啟容器。

### 6. 管理使用者帳號

帳號存在內建 IdP（本地帳號），由 owner 在 Dashboard 建立；使用者依 `USAGE.md` 洽管理者申請，提供姓名與 email。

#### 建立帳號

以 owner 登入 Dashboard → 左側 Team → Users → **Add User**，在對話框填寫：

| 欄位 | 填法 |
|---|---|
| Name | 使用者姓名 |
| Email | 使用者 email，也是登入帳號 |
| Role | 一般使用者維持預設 `User` |
| Auto-assigned groups | 選 `Remote-Users`；沒選就沒有任何網段權限（〈5. 設權限〉只放行此群組） |

建立方式由對話框上方的分頁切換，二擇一：

| 方式 | Dashboard 的結果 | 交給使用者 | 適用 |
|---|---|---|---|
| **Invite User**（預設分頁，建議） | 按 Create Invite Link 產生邀請連結，`Expires in` 可設天數（預設 3 天） | 邀請連結，提醒在期限內開啟並自設密碼 | 一般情況，密碼不經管理者 |
| **Create User** | 按 Create User 直接建立帳號，系統產生密碼，只顯示一次 | email 與密碼，以私訊等安全管道分開傳送 | 使用者無法自行開連結時 |

完成時對話框會顯示連結或密碼，按 **Copy & Close** 複製後關閉；關閉後無法再看到密碼。

#### 交付與確認

1. 把連結或密碼、伺服器網址 `https://netbird.wan.example.com` 與說明頁網址 `https://<VPN_GUIDE_DOMAIN>` 交給使用者，請其依 `USAGE.md`〈在公司外〉安裝並登入。
2. 使用者登入後，Dashboard → Peers 會出現其裝置，所屬使用者為其 email。
3. 請使用者執行 `netbird networks list`，看得到〈5〉設定的網段即完成。

#### 後續維護

| 情況 | 做法 |
|---|---|
| 邀請連結過期或遺失 | Users 頁按 **Show Invites** 列出邀請，重新發送或刪除後重建 |
| 使用者沒有網段權限 | 確認其裝置在 `Remote-Users` 群組：Users 列表的 Groups 欄（自動指派給之後新增的裝置），或 Peers → 該裝置的群組 |
| 使用者離職或停用 | Users 刪除該使用者，並到 Peers 刪除其裝置 |
| 登入有效期限 | Settings → Authentication 調整（例：本案設為 1 小時） |

### 7. 啟動使用者說明頁

建置並啟動說明頁（內容為 `USAGE.md`，建置時代入 `.env` 的網域與 DHCP 值），再把網址 `https://<VPN_GUIDE_DOMAIN>` 告知使用者：

```bash
tools/run.sh up vpn-router <主機> --build guide
```

### 8. 啟動 DHCP（先關路由器 DHCP）

先在路由器關閉 DHCP，避免兩台同時發位址；再建置並啟動 dnsmasq（首次會在主機上建映像）：

```bash
tools/run.sh up vpn-router <主機> --build dhcp
```

之後 LAN 筆電重連，確認路由表有 `<DHCP_ROUTE_NET> via <HOST_LAN_IP>` 與 `default via <DHCP_GATEWAY>`。

### 常用操作

啟停與狀態用 `tools/run.sh [up|down|start|stop|restart|list] vpn-router <主機>`（省略指令即列狀態）；其餘在主機 `~/vpn-router/` 執行：

| 目的 | 指令 |
|---|---|
| 改 `.env` 或 `configs` 後套用 | `docker compose up -d --force-recreate <服務>`（只改 configs 內容時 compose 不會自動重建） |
| 改 `USAGE.md`，或改 `.env` 的網域／DHCP 值後更新說明頁 | 先 `tools/install.sh` 同步，再 `docker compose up -d --build guide` |
| 看 log | `docker compose logs -f <服務>` |
| 看 DHCP 租約 | `docker compose exec dhcp cat /var/lib/dnsmasq/dnsmasq.leases` |
| 看 routing peer 狀態 | `docker compose exec netbird netbird status` |
| 停 DHCP（回復路由器 DHCP 前） | `docker compose stop dhcp` |
