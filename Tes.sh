#!/bin/bash

TELEGRAM_TOKEN="${TELEGRAM_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"

if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ Token atau Chat ID tidak ditemukan!"
    exit 1
fi

echo "✅ Token terbaca dari ~/.bashrc"
echo "🔄 Mengirim pesan ke Telegram..."

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=<b>TEST SUKSES</b> 🚀")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Pesan berhasil terkirim!"
else
    echo "❌ Gagal. Log: $RESPONSE"
fi
