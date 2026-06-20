#!/bin/bash

# ==========================================
# ⚙️ Baca Token: env var → argumen → error
# ==========================================
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-$1}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-$2}"

# ==========================================
# 🔒 Validasi Keamanan
# ==========================================
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ Error: Token atau Chat ID tidak ditemukan!"
    echo ""
    echo "💡 Opsi penggunaan:"
    echo "  1. Set env var dulu:"
    echo "     export TELEGRAM_TOKEN='xxx'"
    echo "     export TELEGRAM_CHAT_ID='xxx'"
    echo "     bash .script.sh"
    echo ""
    echo "  2. Atau lewat argumen (tidak direkomendasikan):"
    echo "     bash .script.sh 'TOKEN' 'CHAT_ID'"
    exit 1
fi

echo "✅ Token dan ID berhasil terbaca dengan aman!"
echo "🔄 Mengirim pesan test ke Telegram..."

# ==========================================
# 📨 Kirim Pesan Telegram
# ==========================================
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=<b>TEST SUKSES</b> 🚀%0A├─ 💻 <b>Host:</b> $(hostname)%0A└─ 🔒 <b>Status:</b> Token Aman (Dari env var)")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Pesan berhasil terkirim!"
else
    echo "❌ Gagal mengirim pesan."
    echo "Log error: $RESPONSE"
fi    echo "Log error: $RESPONSE"
fi
