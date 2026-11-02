# VPN 分流使用說明

> 何時讀：要連經公司轉送的網段（例：`10.10.0.0/16`），或在公司外要連公司 LAN 時。本文即說明頁 `https://vpn.lan.example.com` 的內容，只能在公司 LAN 或已連上 NetBird 時開啟。

## 你屬於哪一種

依你所在的位置，連線方式不同：

| 你在哪裡 | 連經公司轉送的網段 | 連公司 LAN | 要做什麼 |
|---|---|---|---|
| 公司 LAN／WiFi | 自動經轉送主機 | 本來就在 LAN 內 | 不用安裝任何東西，見〈在公司內〉 |
| 公司外 | 經 NetBird | 經 NetBird | 申請帳號並安裝 NetBird，見〈在公司外〉 |

## 在公司內（DHCP）

### 自動取得的設定

連上公司 LAN 或 WiFi 後，電腦會從 DHCP 自動取得下列設定，不必手動設定：

| 項目 | 值 |
|---|---|
| IP 位址範圍 | `192.168.1.100` – `192.168.1.199` |
| 預設閘道 | `192.168.1.1` |
| DNS | `8.8.8.8,168.95.1.1` |
| 分流路由 | `10.10.0.0/16` 經轉送主機 `192.168.1.21` |
| 租期 | `12h` |

只有分流路由的網段經轉送主機，其他上網照舊走預設閘道。

### 確認分流

對分流路由網段內任一 IP 查詢路由（以下以 10.10.0.1 為例），結果顯示經轉送主機的 IP 即為正常：

| 系統 | 指令 |
|---|---|
| Windows | `route print 10.10.*` |
| macOS | `route -n get 10.10.0.1` |
| Linux | `ip route get 10.10.0.1` |

### 連不到時

- **重新取得設定**：關掉網路再開；或 Windows 執行 `ipconfig /renew`，macOS 到「系統設定 → 網路 → 詳細資訊 → TCP/IP → 更新 DHCP 租約」。
- **手動設固定 IP 的電腦**：收不到分流路由，請改回自動取得，或洽 IT 管理者。
- **NetBird 仍連著**：在公司內請先中斷 NetBird。

## 在公司外（NetBird）

### 1. 申請帳號

洽 IT 管理者申請，提供姓名與 email。管理者建好帳號後，你會收到下列其中一種：

- **邀請連結**：在期限內（通常 3 天）開啟，自行設定密碼。
- **初始密碼**：管理者另外告知，登入時使用。

之後一律用這組 email 與密碼登入 NetBird。

### 2. 安裝 NetBird

到官方下載頁 <https://netbird.io/download> 安裝對應系統的版本（Windows、macOS、Linux、iOS、Android）。

### 3. 設定伺服器並登入

NetBird 預設連官方雲端，要改成公司的伺服器 `https://netbird.wan.example.com`：

- **桌面版**：在 NetBird 圖示選單的設定中，把 Management URL 改成上述網址。
- **命令列**：執行下列指令。

```bash
netbird up --management-url https://netbird.wan.example.com
```

接著瀏覽器會開登入頁，用申請到的帳號登入；完成後 NetBird 顯示已連線。

### 4. 確認連線

執行下列指令，`Management`、`Signal` 為 `Connected`，且 `Peers count` 至少 `1/1 Connected` 即正常：

```bash
netbird status
```

### 使用注意

- **只轉送必要流量**：只有公司指定的網段經 NetBird（實際網段可用 `netbird networks list` 查），其他上網照舊走當地網路。
- **連轉送主機上的服務**：直接用轉送主機 IP（`192.168.1.21`）加 port。
- **定期重新登入**：登入有效期限到了，NetBird 會要求重新登入。
- **回到公司內**：請中斷 NetBird（選單的 Disconnect，或執行 `netbird down`）。
- **當地網路與公司 LAN 同網段**：可能連不到公司 LAN，請洽 IT 管理者。
