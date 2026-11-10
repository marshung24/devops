# 內網 image 暫存區（registry.lan.example.com）

> 何時讀：要把自建 image 推到內網主機部署，或查這裡有哪些 image 時。本文即說明頁 `https://registry.lan.example.com`（只限 LAN 與 NetBird 來源）的內容。
>
> **用途限制**：本服務只為支援**內網開發部署的映像檔暫存與差異傳輸**（push／pull 只傳對方缺少的 layer）。不是正式版本庫，不保證保存，空間不足時可能整庫清空；要留存的 image 請自備來源可重建。**暫不提供帳密**，存取只靠來源網段限制。

## 映像檔清單

<div id="images"></div>

大小為壓縮後 layer 總和（pull 的最大傳輸量）；多平台 image 每個 tag 只列一個平台：優先 `linux/amd64`，沒有才列其他平台（見平台欄）。**刪除**只移除該 tag，同一內容的其他 tag 保留；磁碟空間待維運者清理後才釋放。

## 使用

image 路徑為 `registry.lan.example.com/<名稱>:<tag>`，不帶 `https://`。憑證為 Let's Encrypt，不必設 `insecure-registries`，也不必 `docker login`。

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
| 刪除 tag | `curl -X DELETE https://registry.lan.example.com/v2/<名稱>/manifests/<tag>` |
| 不經 docker daemon 複製、檢視 | [crane](https://github.com/google/go-containerregistry/tree/main/cmd/crane)、[regctl](https://github.com/regclient/regclient)、[skopeo](https://github.com/containers/skopeo) |

用完的 tag 請自行刪除，避免佔滿空間。

## 安全須知

- **任何人都能覆寫與刪除**：LAN 與 NetBird 內任何人都可 push、覆寫同名 tag、刪除 tag，刪了無法復原；只刪自己推的，部署前確認來源，重要部署用 digest。
- **任何人都能讀取**：🚫 不要推含密鑰的 image（`.env`、私鑰、token、帳密寫進 layer 或 build args）；推上來就可能已被拉走，刪除也收不回，即視為外洩。
- **只限內網開發**：🚫 不作為正式環境或對外服務的 image 來源，也不要把這裡的 image 再散布出去。
