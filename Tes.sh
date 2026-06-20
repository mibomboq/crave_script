#!/bin/bash

# ==========================================
# ⚙️ Baca Token dari ~/.bashrc (env var)
# ==========================================
TELEGRAM_TOKEN="${TELEGRAM_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"

# ==========================================
# 🔒 Validasi
# ==========================================
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ Error: Token atau Chat ID tidak ditemukan!"
    echo "💡 Jalankan dulu:"
    echo "   echo 'export TELEGRAM_TOKEN=\"token_kamu\"' >> ~/.bashrc"
    echo "   echo 'export TELEGRAM_CHAT_ID=\"chatid_kamu\"' >> ~/.bashrc"
    echo "   source ~/.bashrc"
    exit 1
fi

echo "✅ Token terbaca dari ~/.bashrc"
echo "🔄 Mengirim pesan test ke Telegram..."

# ==========================================
# 📨 Kirim Pesan Telegram
# ==========================================
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=<b>TEST SUKSES</b> 🚀%0A├─ 💻 <b>Host:</b> $(hostname)%0A└─ 🔒 <b>Status:</b> Token dari ~/.bashrc")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Pesan berhasil terkirim!"
else
    echo "❌ Gagal mengirim pesan."
    echo "Log: $RESPONSE"
fi
