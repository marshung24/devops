# 說明頁：靜態 nginx，index.html 於瀏覽器端渲染 USAGE.md 並查詢同網域 /v2 API 列出 image
FROM nginx:1.30.5-alpine
COPY guide/index.html USAGE.md /usr/share/nginx/html/
# 把 USAGE.md 的通用示例網域換成本環境的值；非 443 時 image 路徑與網址都要帶 :port（值由 compose build args 帶入 .env）
ARG REGISTRY_DOMAIN REGISTRY_PUBLIC_PORT=443
RUN p=""; [ "$REGISTRY_PUBLIC_PORT" = 443 ] || p=":$REGISTRY_PUBLIC_PORT"; \
    sed -i "s/registry\.lan\.example\.com/$REGISTRY_DOMAIN$p/g" /usr/share/nginx/html/USAGE.md
