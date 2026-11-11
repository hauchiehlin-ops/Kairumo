#!/usr/bin/env bash
#
# scripts/ci-install-linux-deps.sh
# 健全化 GitHub Actions Linux Runner 的系統套件安裝
# 具備 DNS 容錯、Acquire::Retries 重試、--fix-missing 與指數退避機制
#

set -euo pipefail

# 若 /etc/resolv.conf 缺乏備援 nameserver，補上 8.8.8.8 與 1.1.1.1 避免 Azure DNS 偶發逾時
if [ -f /etc/resolv.conf ] && ! grep -q "8.8.8.8" /etc/resolv.conf 2>/dev/null; then
  echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null || true
  echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null || true
fi

PACKAGES=("$@")
if [ ${#PACKAGES[@]} -eq 0 ]; then
  PACKAGES=("libasound2-dev" "pkg-config")
fi

echo "開始安裝 Linux 系統相依套件: ${PACKAGES[*]}"

MAX_RETRIES=5
for attempt in $(seq 1 $MAX_RETRIES); do
  echo "==> 安裝嘗試 $attempt / $MAX_RETRIES..."
  if sudo apt-get update -o Acquire::Retries=5 && \
     sudo apt-get install -y --fix-missing \
       -o Acquire::Retries=5 \
       -o Dpkg::Options::="--force-confdef" \
       -o Dpkg::Options::="--force-confold" \
       "${PACKAGES[@]}"; then
    echo "✅ Linux 系統相依套件安裝成功。"
    exit 0
  fi
  echo "⚠️ 嘗試 $attempt 失敗，等候 $((attempt * 3)) 秒後重試..."
  sleep $((attempt * 3))
done

echo "❌ 在重試 $MAX_RETRIES 次後仍無法安裝 Linux 相依套件。"
exit 1
