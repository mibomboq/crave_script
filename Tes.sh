#!/bin/bash

# ==========================================
# ⚙️ Menerima Input dari Termux
# ==========================================
# $1 adalah argumen pertama (Token)
# $2 adalah argumen kedua (Chat ID)
TELEGRAM_TOKEN="$1"
TELEGRAM_CHAT_ID="$2"

# ==========================================
# 🔒 Validasi Keamanan
# ==========================================
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ Error: Token atau Chat ID tidak disertakan!"
    echo "💡 Cara pakai di Termux:"
    echo "curl -LSs <LINK_RAW_GITHUB> | bash -s 'TOKEN_BOT' 'CHAT_ID'"
    exit 1
fi

echo "✅ Token dan ID berhasil terbaca dengan aman di Termux!"
echo "🔄 Mengirim pesan test ke Telegram..."

# ==========================================
# 📨 Fungsi Kirim Pesan Telegram
# ==========================================
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=<b>TEST SUKSES</b> 🚀%0A├─ 💻 <b>Host:</b> Termux%0A└─ 🔒 <b>Status:</b> Token Aman (Tidak di-hardcode)")

# Cek apakah pesan benar-benar terkirim
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Pesan berhasil terkirim! Silakan cek grup/bot Telegram kamu."
else
    echo "❌ Gagal mengirim pesan. Cek kembali Token atau Chat ID kamu."
    echo "Log error: $RESPONSE"
fi
