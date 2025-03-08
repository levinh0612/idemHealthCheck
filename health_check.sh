#!/bin/bash

# Thông tin cấu hình từ biến môi trường
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

# Mảng danh sách các server cần ping (chỉ cần host)
SERVERS=(
    "192.168.1.206:8080"  # Server 1
    "staging-idempiere.fahasa.com"  # Server 2
    "erp-ops.fahasa.com"      # Server 3
)

# Mảng danh sách các database cần kiểm tra (format: "host:port")
DATABASES=(
    "192.168.1.206:9999"      # Database 1
    "192.168.13.128:5432"  # Database 2 (ví dụ PostgreSQL)
    "192.168.15.114:5432" # Database 3
)

# Hàm gửi thông báo qua Telegram
send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown"
}

# Kiểm tra kết nối với bot Telegram khi khởi động lần đầu
FIRST_RUN_FILE="/app/.firstrun"
if [ ! -f "$FIRST_RUN_FILE" ]; then
    # Test kết nối với bot
    if curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="Test connection" > /dev/null 2>&1; then
        send_telegram_message "✅ *Bot check health idem đã được chạy vào lúc:* `date '+%Y-%m-%d %H:%M:%S'`"
        touch "$FIRST_RUN_FILE"  # Đánh dấu đã chạy lần đầu
    else
        echo "Lỗi: Không thể kết nối với Telegram API. Kiểm tra TELEGRAM_BOT_TOKEN và TELEGRAM_CHAT_ID."
    fi
fi

# Kiểm tra server bằng ping
for SERVER_HOST in "${SERVERS[@]}"; do
    ping -c 4 "$SERVER_HOST" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        send_telegram_message "🚨 *Cảnh báo:* Server $SERVER_HOST không phản hồi (ping thất bại)!"
    fi
done

# Kiểm tra database bằng telnet
for DB in "${DATABASES[@]}"; do
    # Tách host và port từ chuỗi DB
    DB_HOST=$(echo "$DB" | cut -d':' -f1)
    DB_PORT=$(echo "$DB" | cut -d':' -f2)

    (echo > /dev/tcp/"$DB_HOST"/"$DB_PORT") > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        send_telegram_message "🚨 *Cảnh báo:* Không thể kết nối đến database $DB_HOST:$DB_PORT (telnet thất bại)!"
    fi
done