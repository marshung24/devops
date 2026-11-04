# DHCP-only dnsmasq；設定由 compose configs 掛入 /etc/dnsmasq.conf
FROM alpine:3.24
RUN apk add --no-cache dnsmasq
ENTRYPOINT ["dnsmasq", "--keep-in-foreground", "--log-facility=-", "--conf-file=/etc/dnsmasq.conf"]
