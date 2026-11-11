#!/usr/bin/env bash
# 建立與 fetuser 同權限（sudo＋docker 等附加群組）的帳號，並可選擇放入 ssh 公鑰。
# 在目標主機上以有 sudo 的帳號執行：
#   sudo bash create-admin-user.sh [-k '<ssh 公鑰內容>'] [-p '<密碼雜湊>'] <帳號>
# 密碼（sudo 時要用）：給 -p 則直接套用雜湊（產生：openssl passwd -6），帳號已存在也會覆寫；
# 未給則建帳號時互動詢問。
set -euo pipefail

usage() { echo "用法：sudo bash $0 [-k '<ssh 公鑰內容>'] [-p '<密碼雜湊>'] <帳號>" >&2; exit 1; }
pubkey='' hash=''
while getopts k:p: opt; do
  case $opt in
    k) pubkey=$OPTARG ;;
    p) hash=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -eq 1 ]] || usage
[[ -z $hash || $hash == \$* ]] || { echo "-p 需為 crypt 雜湊（openssl passwd -6 產生），不是明碼" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "請用 sudo 執行" >&2; exit 1; }
user=$1
groups=adm,cdrom,sudo,dip,plugdev,lxd,docker

# 建帳號：已存在則跳過，只補密碼、群組與公鑰
if id "$user" &>/dev/null; then
  echo "帳號 $user 已存在，略過建立"
else
  # 互動設密碼需要 tty，建帳號前先擋下
  [[ -n $hash || -t 0 ]] || { echo "需要 tty 才能設定密碼，請用 ssh -t 執行或改給 -p" >&2; exit 1; }
  adduser --disabled-password --gecos "" "$user"
  # 新帳號未給 -p：自行跑 passwd，失敗即中止，不會給沒有密碼的帳號 sudo 群組
  [[ -n $hash ]] || passwd "$user"
fi

# 密碼雜湊：有給才套用
[[ -z $hash ]] || echo "$user:$hash" | chpasswd -e

# 附加群組：對齊 fetuser，主機上沒有的群組略過
for g in ${groups//,/ }; do
  if getent group "$g" >/dev/null; then usermod -aG "$g" "$user"; else echo "略過不存在的群組：$g"; fi
done

# ssh 公鑰：有給才寫入，已有相同內容就不重複
if [[ -n $pubkey ]]; then
  home=$(getent passwd "$user" | cut -d: -f6)
  # 主要群組不一定與帳號同名（既有帳號可能是 users 等）
  group=$(id -gn "$user")
  install -d -m 700 -o "$user" -g "$group" "$home/.ssh"
  keys=$home/.ssh/authorized_keys
  touch "$keys"
  grep -qxF "$pubkey" "$keys" || echo "$pubkey" >> "$keys"
  chown "$user:$group" "$keys"
  chmod 600 "$keys"
fi

id "$user"
