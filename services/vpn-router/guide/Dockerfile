# 使用者說明頁：靜態 nginx，index.html 於瀏覽器端渲染 USAGE.md
FROM nginx:1.30.5-alpine
COPY guide/index.html USAGE.md /usr/share/nginx/html/
COPY assets /usr/share/nginx/html/assets
# 把 USAGE.md 的通用示例（.env.example 的值、443 無 port 的網址）換成本環境的值（由 compose build args 帶入 .env）
ARG NB_DOMAIN NB_PUBLIC_PORT=443 VPN_GUIDE_DOMAIN HOST_LAN_IP \
    DHCP_POOL_START DHCP_POOL_END DHCP_GATEWAY DHCP_DNS DHCP_ROUTE_NET DHCP_LEASE_TIME
# DHCP 值只換反引號內的完整值，避免 192.168.1.1 誤中 192.168.1.100 等前綴
RUN p=""; [ "$NB_PUBLIC_PORT" = 443 ] || p=":$NB_PUBLIC_PORT"; \
    sed -i -e "s#https://netbird\.wan\.example\.com#https://$NB_DOMAIN$p#g" \
      -e "s#https://vpn\.lan\.example\.com#https://$VPN_GUIDE_DOMAIN$p#g" \
      -e "s#\`192\.168\.1\.100\`#\`$DHCP_POOL_START\`#g" -e "s#\`192\.168\.1\.199\`#\`$DHCP_POOL_END\`#g" \
      -e "s#\`192\.168\.1\.1\`#\`$DHCP_GATEWAY\`#g" -e "s#\`8\.8\.8\.8,168\.95\.1\.1\`#\`$DHCP_DNS\`#g" \
      -e "s#\`10\.10\.0\.0/16\`#\`$DHCP_ROUTE_NET\`#g" -e "s#\`192\.168\.1\.21\`#\`$HOST_LAN_IP\`#g" \
      -e "s#\`12h\`#\`$DHCP_LEASE_TIME\`#g" \
      /usr/share/nginx/html/USAGE.md
