# 分流路由方案（DHCP＋自架 NetBird）

> 狀態：已上線（舉例環境：minipc-01，含控制面、routing peer、使用者說明頁與 DHCP）。
> 何時讀：要在一台 LAN 主機上建立、維運或回復本分流時；要知道為何這樣設計、路由與權限契約、上線驗收與風險。部署步驟讀 `services/vpn-router/README.md`。

## 1. 目標

路由器無法提供 VPN 或靜態路由時，改由 LAN 內一台主機（下稱**轉送主機**）把**目標網段**的流量送往專線，並讓遠端使用者能進 LAN；其餘流量不變：

```text
LAN 筆電 ──DHCP Option 121──→ 轉送主機 ──→ 專線 ──────→ 目標網段
遠端筆電 ──NetBird────────────→ 轉送主機 ──→ 專線 ──────→ 目標網段
遠端筆電 ──NetBird────────────→ 轉送主機 ──→ LAN 介面 ──→ LAN
其他流量：LAN 走原閘道、遠端走當地網路
```

舉例：本案路由器（192.168.1.1）的 VPN 與靜態路由故障，轉送主機為 minipc-01（192.168.1.21），目標網段 10.10.0.0/16 經 4G dongle，LAN 為 192.168.1.0/24。

🚫 不得影響轉送主機上既有的連線與服務（例：ppp0 公司 VPN、主機 nginx 與業務容器）。

## 2. 前提

轉送主機須先具備下列條件，本方案不負責建立：

- **往目標網段的路由與轉送**：`ip_forward=1`、FORWARD 放行 LAN ↔ 目標網段、往目標網段 MASQUERADE，且重開機後仍在。舉例：本案 dongle 介面 `enxd23ab9ed64c4`（192.168.0.21/24），`10.10.0.0/16 via 192.168.0.1` 由 root cron 每分鐘維護，iptables 規則持久化於 `/etc/iptables/rules.v4`。
- **對外入口**：路由器能把 HTTPS port 轉送到轉送主機；建議一併轉送 WireGuard 51820/udp，P2P 較易建立。主機 443 已被佔用時改用其他 port；舉例：本案主機 nginx 佔用 80/443，入口改用 8443。
- **NAT loopback**：路由器不支援時，LAN 內連不到對外網域；舉例：本案即不支援，見 §4〈本機回連〉。

⇒ 本方案只補兩件事：讓用戶端把目標網段送到轉送主機，以及遠端可註冊的 NetBird 控制面。

## 3. 選案

| 決策 | 採用 | 未採 |
|---|---|---|
| LAN 分流 | **DHCP Option 121 只把目標網段指向轉送主機** | 轉送主機當全體預設閘道：故障面擴大到全部上網；僅在端點不支援 121 時改用 |
| NetBird 控制面 | **自架 Community Edition**（官方合併式 `netbird-server`＋dashboard，內建 IdP，人數不限） | NetBird Cloud：免費方案上限 5 人 |
| P2P 位址探測（STUN） | **公共 STUN**（例：Cloudflare、Google），細節見 §4〈STUN〉 | 內建 STUN：routing peer 只取得 LAN IP，P2P 建不起來；`external-ip-map` 宣告公網 IP：DDNS 浮動須另寫偵測與重建 |
| 控制面入口 | **接入主機上的共用反向代理**（例：共用 Traefik，選案與接入契約讀 [docs/traefik](../traefik/README.md)） | 掛主機既有 nginx：要改正式環境設定並加 gRPC |
| 使用者說明頁 | **`https://vpn.<LAN 網域>`，只限 LAN、NetBird 與其他內部來源**；帳號申請寫「洽 IT 管理者」 | 對網際網路公開：遠端新使用者裝好前也能看，但內容含內部網段與 IP（遠端新使用者改由管理者告知安裝方式） |

## 4. 設定

### DHCP（dnsmasq，取代路由器 DHCP）

- 只能有一台 DHCP：取代路由器 DHCP，不並存。
- 用 DHCP 選項把路由發給用戶端：

  | 選項 | 內容 |
  |---|---|
  | Option 3（Router） | 預設閘道 `DHCP_GATEWAY`（例：192.168.1.1） |
  | Option 121（Classless Static Route，RFC 3442） | 靜態路由清單，靠它把目標網段指向轉送主機 |
  | Option 249 | 微軟私有版的 121，內容相同，給只認 249 的舊版 Windows |

  用戶端收到 121 就會忽略 Option 3，所以 121 要連預設路由 `0.0.0.0/0 → DHCP_GATEWAY` 一起寫，否則用戶端會沒有預設閘道而斷網。
- `port=0` 關掉 DNS，避免與主機的 systemd-resolved 衝突。

### NetBird 控制面（自架）

- **入口**：`https://<NB_DOMAIN>`（例：`netbird.wan.example.com`；入口 port 非 443 時網址要帶 port），用共用反向代理的對外網域與萬用字元憑證，不另設 DNS；不走 Cloudflare proxy（gRPC 無法經其代理）。只用單一網域：NetBird 的對外位址與 OIDC issuer 只能有一個，雙網域會使登入導向不符。
- **對外**：HTTPS port（經反向代理）；WireGuard 51820/udp 建議轉送到轉送主機。
- **STUN**：用公共 STUN（例：Cloudflare、Google），不啟用內建 STUN。內建 STUN 與控制面同網域，routing peer 經〈本機回連〉的 `extra_hosts` 會問到 LAN 上的自己，只取得 LAN IP、宣告不出公網位址，P2P 因而建不起來、一律走 Relay；公共 STUN 在 NAT 外，取得的公網位址也隨 DDNS 自動更新。公共 STUN 只看得到各裝置對外 IP，看不到帳號、設定與 VPN 流量。
- **TLS**：由共用反向代理簽發。
- **帳號**：內建 IdP 本地帳號。owner 在 Dashboard 以 Add User 建立帳號，方式有兩種：直接建立（系統產生密碼，只顯示一次）或邀請連結（使用者自設密碼，連結有期限）；建立時自動加入群組 `Remote-Users`。建議用邀請連結，密碼不經管理者。
- **網路**：dashboard、netbird-server 接入反向代理的共用網路；只有 routing peer 用 host network。
- **本機回連**：routing peer 以 `extra_hosts` 把 `NB_DOMAIN` 指向轉送主機 LAN IP，不依賴 NAT loopback；不支援 NAT loopback 時 LAN 內筆電連不到控制面，NetBird 只供 LAN 外使用。

### NetBird 路由與權限

- **發布網段**：在 Dashboard 設定，不在 `.env`；只發布目標網段與 LAN（例：本案 `10.10.0.0/16` 與 `192.168.1.0/24`），其餘走當地網路；🚫 不開 exit node、不發布其他網段。
- **routing peer**：只有轉送主機，**開 masquerade**（目的端沒有回 NetBird 網段的路由，回程靠它）。
- **權限**：只允許群組 `Remote-Users`，不保留預設全互通 policy。遠端連轉送主機上容器的 mapping port 用 `<HOST_LAN_IP>:<port>`。

### 使用者說明頁

- **對象**：一般使用者（非管理者）；內容為 LAN 內 DHCP 資訊與分流確認、LAN 外帳號申請與 NetBird 安裝登入。
- **內容與網址**：內容為 `services/vpn-router/USAGE.md`，git 中以 `.env.example` 的值與 `wan.example.com` 為通用示例，建置時代入 `.env` 實際值；網址 `VPN_GUIDE_DOMAIN`（`vpn.<LAN 網域>`）。
- **限制來源**：本服務自有 `ipAllowList`，來源清單 `VPN_GUIDE_ALLOW` 由 `.env` 設定（例：本案 LAN 192.168.1.0/24、NetBird 100.64.0.0/10、舊路由器 VPN 10.8.0.0/24）；經反向代理只用其路由與 TLS，不依賴其內部元件。

### 部署檔

實作在 `services/vpn-router/`，參數與密鑰由 `.env` 設定。要部署、設 Dashboard、建帳號、查 port 或變數時讀 `services/vpn-router/README.md`。

## 5. 上線、風險與回復

**上線**（使用方式指 `services/vpn-router/README.md`；先備份 `ip route`／`iptables-save`，並記錄轉送主機既有連線與服務的狀況當基線）：

1. **控制面**（使用方式步驟 1–3）：用外網（例：手機 4G）開 `https://<NB_DOMAIN>`，能完成 `/setup` 並登入。
2. **routing peer、路由與帳號**（使用方式步驟 4–6）：用外網筆電登入後，連得到目標網段與 LAN 主機（例：本案 10.10.10.215 與 192.168.1.1），並測轉送主機上容器的 mapping port；routing peer 上看該 peer 為 `Connection type: P2P`（Relayed 表示 P2P 未建立，見 §4〈STUN〉）。
3. **使用者說明頁**（使用方式步驟 7）：LAN 與 NetBird 遠端可開 `https://<VPN_GUIDE_DOMAIN>`，內容為實際值；外網回 403。
4. **DHCP**（使用方式步驟 8）：LAN 筆電重連，確認路由表有 `<目標網段> via <HOST_LAN_IP>` 與 `default via <DHCP_GATEWAY>`。
5. 比對基線，並另約時段重開轉送主機驗證自動恢復。

**風險**

| 風險 | 後果與對策 |
|---|---|
| 端點不支援 121 | 目標網段不通；步驟 4 逐台確認，不支援者改用 NetBird 或改以轉送主機當閘道 |
| 遠端當地網段與 LAN 相同 | 連不到 LAN 或當地 LAN 中斷（依 OS 而定）；該使用者改當地網段。舉例：本案發布整段 192.168.1.0/24，已接受此風險 |
| 雙 DHCP 同時應答 | IP 衝突；嚴守步驟 4 先關路由器 DHCP |
| 公共 STUN 無法使用 | 新連線無法打 P2P、改走 Relay（較慢但可用）；列兩家互為備援 |
| 轉送主機停機 | 遠端與 LAN 都無法到目標網段、拿不到新租約；依回復程序處理 |
| NetBird 改寫主機規則 | 可能影響既有連線與服務；以基線比對 |

**回復**：DHCP：停 dhcp → 開回路由器 DHCP → 用戶端重連。NetBird：`docker compose stop netbird`，控制面可留著。主機路由、NAT 與既有服務未改動，不需回復。

## 6. 待拍板（本案）

- 權限：目標網段與 LAN 全開，或只開特定服務。
- DHCP：保留位址（位址池、DNS 已定於 `.env`）。
