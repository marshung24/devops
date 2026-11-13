# 說明頁：靜態 nginx，index.html 於瀏覽器端渲染 USAGE.md
FROM nginx:1.30.5-alpine
COPY guide/index.html USAGE.md /usr/share/nginx/html/
# 把 USAGE.md 的通用示例（443、無 port 的網址）換成本環境的根網域與 port（值由 compose build args 帶入 .env）
ARG TRAEFIK_BASE_DOMAIN TRAEFIK_LAN_DOMAIN TRAEFIK_LEGACY_LAN_DOMAIN TRAEFIK_PUBLIC_PORT=443
# 非 443 時網址要帶 :port
# 沒有對外網域時移除外網示例、沒有舊內網網域時移除並行期說明，須先於網域代換
RUN p=""; [ "$TRAEFIK_PUBLIC_PORT" = 443 ] || p=":$TRAEFIK_PUBLIC_PORT"; \
    [ -n "$TRAEFIK_LEGACY_LAN_DOMAIN" ] || sed -i '/legacy\.example\.com/d' /usr/share/nginx/html/USAGE.md; \
    [ -n "$TRAEFIK_BASE_DOMAIN" ] || sed -i -e '/^| 外網 /d' -e '/確定要開外網時/d' -e '/外網網址會對所有人開放/d' \
      -e 's/a\.b\.wan\.example\.com/a.b.lan.example.com/' /usr/share/nginx/html/USAGE.md; \
    sed -i -e "s#\(https://[^\`]*\.example\.com\)#\1$p#g" -e "s/:443 /:$TRAEFIK_PUBLIC_PORT /g" \
      -e "s/wan\.example\.com/$TRAEFIK_BASE_DOMAIN/g" -e "s/lan\.example\.com/$TRAEFIK_LAN_DOMAIN/g" -e "s/legacy\.example\.com/$TRAEFIK_LEGACY_LAN_DOMAIN/g" \
      /usr/share/nginx/html/USAGE.md
