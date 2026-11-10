# 內網開發用 image 暫存區

> 狀態：設計完成，未上線。
> 何時讀：要調整存取邊界、儲存、清理方式或說明頁時。要部署讀 `services/docker-registry/README.md`；要使用讀 `services/docker-registry/USAGE.md`（即說明頁內容）。

## 1. 目標

內網開發部署容器時，有一處暫存自建 image、只傳差異 layer 的 registry；以 `tools/install.sh` 同步到遠端主機、`tools/run.sh` 啟動，不在使用端本機架設。

範圍限單機、開發測試用途，image 皆可重建；不提供帳號權限、tag 保護、自動保留策略與多架構建置設定。🚫 不佔用主機 port、不影響既有服務。

## 2. 選案

| 決策 | 採用 | 未採 |
|---|---|---|
| 軟體 | **`registry:3`（CNCF Distribution）單一容器** | Harbor：多容器、需 DB 與 Redis，超出需求 |
| 入口 | **主機共用 Traefik**（`traefik-proxy`、`tls=true`），沿用萬用字元憑證，不 publish port | 直接 publish 主機 port：繞過 TLS 與來源限制，使用端要設 `insecure-registries` |
| 網域 | **`REGISTRY_DOMAIN`，用內網根網域下一層** | 對外網域：外網不需使用 |
| 說明頁 | **自製說明頁（nginx＋單頁 HTML），與 registry 同網域**：Traefik 依路徑分流，`/v2` 直達 registry、其餘給說明頁；頁面渲染 `USAGE.md`（用途限制、命令列工具、安全須知），並在瀏覽器以同網域 `/v2` API 列出 image、tag、大小、建立時間，可逐 tag 刪除；多平台每個 tag 只列一個平台，優先 `linux/amd64` | joxit/docker-registry-ui：放不進用途與安全須知、示例無法代入網域與 port；另取網域：多一個名稱要記 |
| 存取控制 | **規則內以 `ClientIP` 限私有網段與 NetBird（100.64.0.0/10），無認證**；與 Traefik 說明頁同一組網段 | 只寫內網名稱：hostname 不是安全邊界，minipc-01 外網帶 Host 即可寫入；push 認證（Traefik 依方法拆 router 加 basicAuth）或全站 htpasswd：每台使用端與部署主機都要登入，開發測試不需區分身分 |
| 儲存 | **主機目錄 bind mount，路徑由 `.env` 的 `REGISTRY_DATA_DIR` 指定**，放容量足夠的資料碟、服務目錄外：路徑看得到，查用量、備份、搬移方便 | named volume：位置由 Docker 決定，查用量與搬移不便；服務目錄內：`tools/install.sh` 同步時刪除主機多餘檔案，會刪掉資料 |
| 清理 | **開放 DELETE API，使用者自行刪 tag；維運者在主機停 registry 跑 GC（`--delete-untagged`）釋放空間**；必要時整庫重置 | 關閉 DELETE、只整庫重置：無法只清舊 image，空間只增不減；DELETE 加認證：要管帳密，開發測試不需要 |

## 3. 設定

- **來源判定**：Traefik 看到的來源 IP。跨主機轉送經 PROXY protocol 保留真實來源（見 docs/traefik §4〈跨主機轉送〉），外網來源不匹配、回 404；內網經防火牆 hairpin 時來源是公網 IP，同樣被擋，LAN 內一律用內網網域直連。
- **相對 URL**：`REGISTRY_HTTP_RELATIVEURLS=true`，上傳流程的 `Location` 不帶 host 與 port，對外 port 非 443 時不受影響。
- **大檔與長連線**：Traefik 未設 body 上限、entrypoint 與後端逾時皆關閉，大 layer 上傳不另調整。

## 4. 上線、風險與回復

**上線驗收**：LAN 內 `curl https://<REGISTRY_DOMAIN>/v2/` 回 `{}`、說明頁列得出已 push 的 image（含多平台 image 的大小與建立時間）；LAN 內 `docker push`、`docker pull` 成功；外網帶相同 Host 連入口回 404；NetBird 遠端 pull 成功。

| 風險 | 後果與對策 |
|---|---|
| 無認證 | LAN／NetBird 內任何人可 push、覆寫、刪除 tag，誤刪無法復原；接 `traefik-proxy` 的容器可直連後端繞過來源限制。開發測試已接受，image 皆可重建；需要區分身分時改採認證 |
| 磁碟用量 | 無容量上限，持續 push 不清理會佔滿 `REGISTRY_DATA_DIR` 所在磁碟，同碟若有 Docker 資料目錄或其他服務會一併受影響；定期看容量、跑 GC，必要時整庫重置 |
| traefik 停機 | registry 無法存取，資料不受影響 |

**回復**：`docker compose down`，`REGISTRY_DATA_DIR` 不受影響、image 保留；要清空需手動刪該目錄。
