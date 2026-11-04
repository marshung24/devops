# devops — AI agent 專案指令

## 專案資訊

- **專案定位**：主機的維運服務（Docker Compose 部署檔、設計規格與 ssh 同步／操作腳本）。
- **工作入口**：
  - 定位任務、找服務 → 根 `README.md`：目錄分工與服務索引。
  - 要改架構、契約、路由、權限或回復程序 → `docs/<主題>/README.md`：目標、前提、選案、驗收與風險；規格先改再改 `services/`。
  - 要部署、調參數或排查 → `services/<服務>/README.md`；變數定義見同目錄 `.env.example`。
  - 要改接入方式或使用者流程 → `services/<服務>/USAGE.md`：同時是該服務說明頁的內容來源。
- **主分支**：`main`
- **測試指令**：不適用：repo 內無測試、Makefile 或 CI 設定。
- **其他必跑檢查**：不適用：同上。
- **產生物**：不適用：無進版控的產生物。服務 README 的作者／最後更新加註由 `tools/install.sh` 安裝時寫到主機，原檔不手寫；說明頁內容在映像建置時由 `USAGE.md` 代入 `.env` 值。
- **需授權的命令**：`tools/install.sh`（不帶 `-n`）、`tools/run.sh` 除 `list` 外的子指令、對主機的 ssh 寫入或 `docker` 操作。`tools/install.sh -n`、`tools/run.sh list` 唯讀，可直接執行。
- **PR 規範**：無專案範本；Body 至少含 Summary、變更項目、Test Plan（指令與結果）。

## 工作規範

- 只改任務範圍內的內容，保留無關的既有變更；沿用 repo 既有架構與慣例。新增服務放 `services/<服務>/`（含 `README.md`、`.env.example`、排除 `.env` 的 `.gitignore`）、設計放 `docs/<服務>/`，並在根 `README.md`〈索引〉加一列。
- 🚫 不在「主分支」上作業，一律開 feature／fix 分支。
- 🚫 未經本次對話授權，不得 push、開或合 PR、推 tag、執行〈需授權的命令〉。改寫已推送的分支只能用 `--force-with-lease`。
- 🚫 不得手改〈產生物〉：改來源、再生、與來源同一個 commit。
- 🚫 不得提交憑證、token、私鑰或個資。實際網域、IP、port 只在主機 `.env`；git 中一律用 `.env.example` 的值與 `wan.example.com`／`lan.example.com`、預設 443 不帶 port。改 `USAGE.md` 示例值時同步檢查對應 `guide/Dockerfile` 的代換規則。
- 🚫 不得影響主機既有服務：不接手主機 nginx 的 80/443/8543/8090，不動轉送主機既有連線（如 ppp0）與業務容器；邊界見各 `docs/<主題>/README.md`〈目標〉。
- 本 repo 部署的是 minipc-01 上的 `traefik`（網路 `traefik-proxy`、`TRAEFIK_BASE_DOMAIN`／`TRAEFIK_LAN_DOMAIN`），接入契約見 `services/traefik/USAGE.md`；與 agent 執行環境的 Traefik（`docker-workspace_proxy`、`BASE_DOMAIN`）無關，🚫 不混用。
- Commit 用 Conventional Commits `type(scope): 中文摘要`（feat／fix／docs／refactor／test／chore），scope 用服務或主題名（例：`vpn-router`、`tools`），依變更目的拆，只含本案內容；🚫 不寫 AI 署名或 `Co-Authored-By`。
- 發現 repo 的 README 或其指向文件不符漸進式披露（指路只丟路徑沒說何時該讀、細節塞在第一層、同一命題在多份文件各寫一份）時，**向使用者提出建議**；🚫 不自行改寫，那超出任務範圍。
- 任何時點改了東西，重跑受影響的檢查。

## 結案流程

**啟動條件**：使用者要求結案、交付或發 PR。一般修改、調查、唯讀諮詢不觸發，也不自行 commit／push／發 PR。

1. **確認完成**：對照使用者本次要求或指定的 Issue AC 逐項核對，兩者皆無則以本次對話的明確要求為準，🚫 不擴張範圍或補建 AC。確認人在本案分支，diff 與未追蹤檔只含本案改動。
2. **跑測試與檢查**：「測試指令」與適用的「其他必跑檢查」全數成功才算過。🚫 無測試不等於通過——回報查證依據與未驗證風險，🚫 不代換命令。
3. **自我 review 並修正**：審本案全部改動（staged／unstaged／untracked）——正確性、安全性、資料風險、需求不符、效能退化、可維護性。有修正就摘要，並重跑受影響的檢查。
4. **顧問 review 並修正**：交給使用者指定的「外部顧問」。它自行讀檔，只給**審查範圍**與**副作用邊界**（例：「相對 `origin/<主分支>` 的本次改動，唯讀」）；🚫 不備 diff、不給檢查清單、不預設結論、不限定角度與方法——要的是它的觀點。意見逐項判斷，🚫 不照單全收；有修正就摘要，並重跑受影響的檢查。未指定顧問先問，使用者明示略過才可繼續並在 PR 註記，🚫 不得以自我 review 充當。
5. **提交並同步主線**：先 commit 到工作樹乾淨，`git fetch` 後 rebase 至最新「主分支」，fetch 失敗即停。衝突解完重看 diff、重跑受影響的檢查。主線帶進本案相依範圍的改動時（無衝突也算），重做第 3 步，必要時連第 4 步。
6. **Push 與發 PR**：對最終 HEAD 重跑測試與檢查、工作樹乾淨才 push。PR base 為「主分支」，標題用 Conventional Commits，Body 依「PR 規範」；建立後核對 base／head、標題、Body、連結。
7. **worktree 收尾**：只處理本次自建的 worktree。先查 staged／unstaged／untracked 與未 push commit，有值得保留的先問使用者；分支已推、PR 已開才移除。

> 每案結案都要發 PR；🚫 RD 不自行合併，上線前由管理者合併。
