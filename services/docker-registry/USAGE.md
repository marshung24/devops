# 內網 image 暫存區（registry.lan.example.com）

> 何時讀：要把自建 image 推到內網主機部署，或查這裡有哪些 image 時。本文即說明頁 `https://registry.lan.example.com`（只限 LAN 與 NetBird 來源）的內容。
>
> **用途限制**：本服務只為支援**內網開發部署的映像檔暫存與差異傳輸**（push／pull 只傳對方缺少的 layer）。不是正式版本庫，不保證保存，空間不足時可能整庫清空；要留存的 image 請自備來源可重建。存取以來源網段限制；寫入（push、刪除）是否要帳密依主機設定，清單一律免登入。

## 映像檔清單

<div id="images"></div>

大小為壓縮後 layer 總和（pull 的最大傳輸量）；多平台 image 每個 tag 只列一個平台：優先 `linux/amd64`，沒有才列其他平台（見平台欄）。**刪除**只移除該 tag，同一內容的其他 tag 保留；磁碟空間待維運者清理後才釋放。

## 使用

image 路徑為 `registry.lan.example.com/<名稱>:<tag>`，不帶 `https://`。憑證為 Let's Encrypt，不必設 `insecure-registries`。出現 `no basic auth credentials` 或 `401 Unauthorized` 即表示有設寫入帳密，先 `docker login registry.lan.example.com`（帳密向維運者索取）：push 一律要登入；pull 在 containerd image store（docker 29 新裝預設、Docker Desktop）免登入，傳統 image store 也要登入。

```bash
# 本機 image 加上 registry 路徑的 tag
docker tag myapp:dev registry.lan.example.com/myapp:dev
# 推上 registry（只傳 registry 缺少的 layer）
docker push registry.lan.example.com/myapp:dev
# 部署端拉下（只傳本機缺少的 layer）
docker pull registry.lan.example.com/myapp:dev
# 或用 buildx 建置後直接推上，不留本機 image；部署主機為 amd64
docker buildx build --platform linux/amd64 -t registry.lan.example.com/myapp:dev --push .
```

- **compose**：服務寫 `image: registry.lan.example.com/myapp:dev`，部署端執行下列指令：

  ```bash
  # 拉取 compose 內所有 image 的最新版
  docker compose pull
  # 以新 image 重建有變動的容器
  docker compose up -d
  ```

- **固定版本**：同名 tag 重推即覆蓋；要可重現的部署，用 digest 指定（`registry.lan.example.com/myapp@sha256:...`）。

## 命令列工具

| 目的 | 指令 |
|---|---|
| 列出 image | `curl https://registry.lan.example.com/v2/_catalog` |
| 列出 tag | `curl https://registry.lan.example.com/v2/<名稱>/tags/list` |
| 看 digest、平台與 layer | `docker buildx imagetools inspect registry.lan.example.com/<名稱>:<tag>` |
| 刪除 tag | `curl -X DELETE https://registry.lan.example.com/v2/<名稱>/manifests/<tag>`（有設寫入帳密時加 `-u <帳號>`） |
| 不經 docker daemon 複製、檢視 | [crane](https://github.com/google/go-containerregistry/tree/main/cmd/crane)、[regctl](https://github.com/regclient/regclient)、[skopeo](https://github.com/containers/skopeo) |

用完的 tag 請自行刪除，避免佔滿空間。

## 不經 registry：OCI layout＋rsync

不想依賴本服務時，可把 image 存成 OCI layout 目錄：每個 layer 是一個以內容雜湊（digest）命名的檔案，同一份 layer 只存一次。再用 rsync 只傳目標端沒有的檔案，一樣做到 layer 級的差異傳輸。

```bash
# 來源端：image 匯出到 OCI layout 目錄；多個 image 可共用同一目錄，以 ref 名稱（冒號後）區分
skopeo copy docker-daemon:myapp:dev oci:/srv/oci-store:myapp-dev
# 傳 layer：檔名即內容雜湊、內容不會變，目標端已有的一律略過（不看修改時間，避免整批重傳）
rsync -a --ignore-existing /srv/oci-store/blobs/ deploy-host:/srv/oci-store/blobs/
# 傳索引：index.json 記錄目錄內有哪些 image，放在 layer 之後傳，避免指到還沒傳到的 layer
rsync -a /srv/oci-store/index.json /srv/oci-store/oci-layout deploy-host:/srv/oci-store/
# 目標端：從 OCI layout 載入 docker
ssh deploy-host skopeo copy oci:/srv/oci-store:myapp-dev docker-daemon:myapp:dev
```

- **前提**：兩端都要有 skopeo，沒裝時可改跑容器 `quay.io/skopeo/stable`，並掛載 `/var/run/docker.sock` 與目錄；兩端之間要能 ssh。
- **要省流量**：兩端都長期沿用同一個目錄，新 image 只會多出變動的 layer。
- **單一來源**：目標端目錄只由一個來源端寫入；`index.json` 整份覆蓋，目標端自己加的 image 會被蓋掉。
- **清理**：目錄只增不減，沒有 GC；空間不足時刪掉整個目錄重來。
- **與 registry 相比**：不需常駐服務，但沒有清單頁，也不方便多人共用；適合固定一對來源、目標的部署。
- **帳號風險**：傳送者需有目標主機的 ssh 帳號與 docker 權限（等同 root）；🚫 不要為了傳 image 開帳號給他人，改用 registry。

## 安全須知

- **覆寫與刪除無法復原**：未設寫入帳密時 LAN 與 NetBird 內任何人都可 push、覆寫同名 tag、刪除 tag；設了也是共用帳密，查不出是誰改的。只刪自己推的，部署前確認來源，重要部署用 digest。
- **任何人都能讀取**：🚫 不要推含密鑰的 image（`.env`、私鑰、token、帳密寫進 layer 或 build args）；推上來就可能已被拉走，刪除也收不回，即視為外洩。
- **只限內網開發**：🚫 不作為正式環境或對外服務的 image 來源，也不要把這裡的 image 再散布出去。
