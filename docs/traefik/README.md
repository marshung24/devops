# minipc-01 共用 Traefik 入口

> 狀態：已上線（minipc-01 `~/traefik/`）。
> 何時讀：要調整共用入口的架構、憑證策略或接入規則時。要部署本服務讀 `services/traefik/README.md`；要把服務接上入口讀 `services/traefik/USAGE.md`（即說明頁內容）。

## 1. 目標

minipc-01 上各 compose project 共用**一個** Traefik 當對外 HTTPS 入口，憑證自動簽發；想接入的人看說明頁就能自行接上。

🚫 不接手主機 nginx 的 80/443/8543/8090（遷移另案）、不影響既有容器。

## 2. 選案

| 決策 | 採用 | 未採 |
|---|---|---|
| 部署單位 | **獨立 project `traefik`**，各服務以外部網路接入 | 放在 vpn-router 內：其 `down` 會斷其他服務入口 |
| 對外入口 | **8443/tcp**（路由器轉送） | 80/443：主機 nginx 佔用 |
| 根網域 | **兩組**：`TRAEFIK_BASE_DOMAIN`（對外）、`TRAEFIK_LAN_DOMAIN`（內網，DNS 指 LAN IP），皆由 `.env` 設定；每個 router 同時列兩者 | 只用對外網域：路由器無 NAT loopback，LAN 內連不到 |
| 憑證 | **Let's Encrypt 萬用字元憑證**，一張涵蓋兩組根網域與其 `*.`，Cloudflare DNS-01；接入方只開 TLS，不另申請 | 各 router 各自申請：每個新網域都要等簽發、消耗頻率額度 |
| 說明頁 | **`https://traefik.<TRAEFIK_LAN_DOMAIN>:8443`，來源 IP 白名單只放 LAN、NetBird 與路由器 VPN**，渲染 `services/traefik/USAGE.md` | 對網際網路公開：內容含內部網段與 IP；另開 LAN 專用 HTTP port：多一個入口與 port；同時掛對外網域：白名單內的使用者都走不到（LAN 無 NAT loopback、遠端經當地網路出去），掛了也沒用 |

## 3. 接入契約

- **組成**：共用網路與網段、Traefik 固定 IP、entrypoint、certresolver、啟用 label、命名前綴；各項的值與寫法讀 `services/traefik/USAGE.md`（說明頁要讓接入者一頁看完，故值只寫在該處）。
- **設計理由**：固定 IP 供接入方設 trusted proxy；`exposedbydefault=false` 防止既有容器被誤路由；命名前綴因 router／service 名稱整台共用。
- **穩定性**：變更任一項即為破壞性變更，須同步所有接入方。

## 4. 設定

- **DNS**：對外根網域跟著 DDNS 指公網 IP；LAN 根網域直接指 .21，LAN 內不經路由器（無 NAT loopback）；皆不走 Cloudflare proxy，以免攔下非標準 port 與 gRPC。兩組都含 `*.`，接入方用根網域下一層的名稱即可，不必再設 DNS。具體記錄讀 `services/traefik/README.md`〈1. Cloudflare DNS〉。
- **TLS**：萬用字元只能用 DNS-01；DNS-01 只需 Cloudflare API 建 TXT，申請與續期不需對外開 80/443；生效檢查查公共 DNS，不受主機（含 ppp0）解析器影響。萬用字元憑證掛在 TLS default store（掛在 router 上無法正確簽出，traefik/traefik#12109），接入方 router 只設 `tls=true` 即以 SNI 取用；根網域外的名稱仍可用 certresolver `le` 單獨申請。
- **gRPC／長連線**：entrypoint 與後端逾時皆關閉，供 NetBird 等長連線服務使用。
- **說明頁**：網域只擋得住解析，擋不住外網直接帶 Host 連 8443，故以 `ipAllowList` 限來源 192.168.1.0/24、NetBird 100.64.0.0/10 與路由器 VPN 10.8.0.0/24（NetBird 取代前的遠端用戶），其餘回 403；NetBird 遠端經已發布的 192.168.1.0/24 連入。內容即 `services/traefik/USAGE.md`，接入規則因此只維護一份；文件在 git 中以 `wan.example.com`／`lan.example.com` 與預設 443（網址不帶 port）為通用示例，建置說明頁時代入 `.env` 的實際根網域，port 非 443 時網址補上 `:<port>`。
- 要部署、查變數、port 或維運指令時讀 `services/traefik/README.md`。

## 5. 上線、風險與回復

**上線驗收**：接入網域的憑證簽發者為 Let's Encrypt（驗證方式見 `services/traefik/USAGE.md`〈驗證憑證〉）；說明頁在 LAN 與 NetBird 遠端可開、外網回 403（已驗證：NetBird 遠端來源 IP 為 100.x，經白名單放行）。

| 風險 | 後果與對策 |
|---|---|
| 接入方重名 | 該路由失效；依 §3 命名規則 |
| 本 project 停機 | 所有接入方對外入口中斷；`restart: unless-stopped`，維運前通知接入方 |
| 網路名稱或 IP 變動 | 接入方連不到或不信任代理標頭；依 §3 視為破壞性變更 |
| Let's Encrypt 頻率限制 | 同網域約每週 5 次；測試先用 staging |

**回復**：`docker compose down`（保留 volume 即保留憑證）；接入方入口同時中斷。
