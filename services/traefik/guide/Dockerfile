# 說明頁：靜態 nginx，index.html 於瀏覽器端渲染 USAGE.md
FROM nginx:1.30.5-alpine
COPY guide/index.html USAGE.md /usr/share/nginx/html/
# 把 USAGE.md 的通用示例（443、無 port 的網址）換成本環境的根網域與 port（值由 compose build args 帶入 .env）
ARG TRAEFIK_BASE_DOMAIN TRAEFIK_LAN_DOMAIN TRAEFIK_PUBLIC_PORT=443
# 非 443 時網址要帶 :port
RUN p=""; [ "$TRAEFIK_PUBLIC_PORT" = 443 ] || p=":$TRAEFIK_PUBLIC_PORT"; \
    sed -i -e "s#\(https://[^\`]*\.example\.com\)#\1$p#g" -e "s/:443 /:$TRAEFIK_PUBLIC_PORT /g" \
      -e "s/wan\.example\.com/$TRAEFIK_BASE_DOMAIN/g" -e "s/lan\.example\.com/$TRAEFIK_LAN_DOMAIN/g" \
      /usr/share/nginx/html/USAGE.md
