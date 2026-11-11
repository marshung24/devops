# 內網開發用 image 暫存區

> 狀態：設計完成，未上線。
> 何時讀：要調整存取邊界、儲存、清理方式或說明頁時。要部署讀 `services/docker-registry/README.md`；要使用讀 `services/docker-registry/USAGE.md`（即說明頁內容）。

## 1. 目標

內網開發部署容器時，有一處暫存自建 image、只傳差異 layer 的 registry；以 `tools/install.sh` 同步到遠端主機、`tools/run.sh` 啟動，不在使用端本機架設。

範圍限單機、開發測試用途，image 皆可重建；寫入（push、刪除）可選擇以共用帳密保護，不提供分帳號權限、tag 保護、自動保留策略與多架構建置設定。🚫 不佔用主機 port、不影響既有服務。

## 2. 選案

| 決策 | 採用 | 未採 |
|---|---|---|
| 軟體 | **`registry:3`（CNCF Distribution）單一容器** | Harbor：多容器、需 DB 與 Redis，超出需求 |
| 入口 | **主機共用 Traefik**（`traefik-proxy`、`tls=true`），沿用萬用字元憑證，不 publish port | 直接 publish 主機 port：繞過 TLS 與來源限制，使用端要設 `insecure-registries` |
| 網域 | **`REGISTRY_DOMAIN`，用內網根網域下一層** | 對外網域：外網不需使用 |
| 說明頁 | **自製說明頁（nginx＋單頁 HTML），與 registry 同網域**：Traefik 依路徑分流，`/v2` 直達 registry、其餘給說明頁；頁面渲染 `USAGE.md`（用途限制、命令列工具、安全須知），並在瀏覽器以同網域 `/v2` API 列出 image、tag、大小、建立時間，可逐 tag 刪除；多平台每個 tag 只列一個平台，優先 `linux/amd64` | joxit/docker-registry-ui：放不進用途與安全須知、示例無法代入網域與 port；另取網域：多一個名稱要記 |
| 存取控制 | **規則內以 `ClientIP` 限私有網段與 NetBird（100.64.0.0/10）**，與 Traefik 說明頁同一組網段 | 只寫內網名稱：hostname 不是安全邊界，minipc-01 外網帶 Host 即可寫入 |
| 寫入認證 | **選用：`.env` 設 `REGISTRY_AUTH_USERS` 時寫入（GET／HEAD 以外的方法）與探測端點 `GET /v2/` 需 Basic 認證，未設時不擋**；以 registry 容器自身的 label 拆 router：讀取 router 只收 `/v2/` 以外的 GET／HEAD、不掛 middleware，其餘走掛 basicAuth 的 router，🚫 不改 Traefik 設定與容器 | registry 內建 htpasswd：只能全站認證，pull 與說明頁清單也要登入；Traefik `usersFile`：帳密檔要放進 Traefik 容器；自建 nginx 代理：多一層轉送與大檔設定 |
| 儲存 | **主機目錄 bind mount，路徑由 `.env` 的 `REGISTRY_DATA_DIR` 指定**，放容量足夠的資料碟、服務目錄外：路徑看得到，查用量、備份、搬移方便 | named volume：位置由 Docker 決定，查用量與搬移不便；服務目錄內：`tools/install.sh` 同步時刪除主機多餘檔案，會刪掉資料 |
| 清理 | **開放 DELETE API，使用者自行刪 tag（設了寫入認證時須帶帳密）；維運者在主機停 registry 跑 GC（`--delete-untagged`）釋放空間**；必要時整庫重置 | 關閉 DELETE、只整庫重置：無法只清舊 image，空間只增不減 |

## 3. 設定

- **來源判定**：Traefik 看到的來源 IP。跨主機轉送經 PROXY protocol 保留真實來源（見 docs/traefik §4〈跨主機轉送〉），外網來源不匹配、回 404；內網經防火牆 hairpin 時來源是公網 IP，同樣被擋，LAN 內一律用內網網域直連。
- **相對 URL**：`REGISTRY_HTTP_RELATIVEURLS=true`，上傳流程的 `Location` 不帶 host 與 port，對外 port 非 443 時不受影響。
- **寫入認證**：`REGISTRY_AUTH_USERS` 為 htpasswd 格式（`htpasswd -nbB`），多組以逗號分隔；compose 以 `${REGISTRY_AUTH_USERS:+…}` 在有值時才替寫入 router 掛 middleware，空值時 middlewares label 為空即不掛（basicAuth 無使用者時引用它的 router 會失效，故不可直接掛）。讀取 router 規則較長，依 Traefik 預設優先序先匹配。`GET /v2/` 是 docker 決定要不要帶帳密的探測端點：開放時 docker 傳統 image store（docker 28 以前、或未改用 containerd image store 者）登入後 push 仍不帶帳密而 401，故設帳密時它也要認證；代價是這類 docker 匿名 pull 也被擋（`no basic auth credentials`），要先 `docker login`。containerd image store（docker 29 新裝預設、Docker Desktop）、crane、curl 與說明頁不受影響，匿名讀取照常。
- **大檔與長連線**：Traefik 未設 body 上限、entrypoint 與後端逾時皆關閉，大 layer 上傳不另調整。

## 4. 上線、風險與回復

**上線驗收**：LAN 內 `curl https://<REGISTRY_DOMAIN>/v2/` 回 `{}`、說明頁列得出已 push 的 image（含多平台 image 的大小與建立時間）；LAN 內 `docker push`、`docker pull` 成功；外網帶相同 Host 連入口回 404；NetBird 遠端 pull 成功。設了寫入認證時另驗：`/v2/` 與未登入 push、DELETE 回 401，登入後 push 成功；說明頁清單免登入。

| 風險 | 後果與對策 |
|---|---|
| 未設寫入認證 | LAN／NetBird 內任何人可 push、覆寫、刪除 tag，誤刪無法復原。開發測試已接受，image 皆可重建；需要時設 `REGISTRY_AUTH_USERS` |
| 設了寫入認證 | 只擋經 Traefik 的寫入；共用帳密無法追查是誰推、誰刪，帳密外流即失效，更換需改 `.env` 並重建 registry 容器。讀取除 docker 傳統 image store（docker 28 以前、或未改用 containerd image store 者）外不需認證，🚫 不推含密鑰的 image |
| 繞過入口 | 接 `traefik-proxy` 的容器可直連後端，繞過來源限制與寫入認證 |
| 磁碟用量 | 無容量上限，持續 push 不清理會佔滿 `REGISTRY_DATA_DIR` 所在磁碟，同碟若有 Docker 資料目錄或其他服務會一併受影響；定期看容量、跑 GC，必要時整庫重置 |
| traefik 停機 | registry 無法存取，資料不受影響 |

**回復**：`docker compose down`，`REGISTRY_DATA_DIR` 不受影響、image 保留；要清空需手動刪該目錄。
