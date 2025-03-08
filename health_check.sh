#!/bin/bash

# Thông tin cấu hình từ biến môi trường (dùng làm mặc định nếu không chỉ định)
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

# Mảng danh sách các server cần ping (chỉ cần host)
SERVERS=(
    "192.168.1.206"  # Server 1
    "staging-idempiere.fahasa.com"  # Server 2
)

# Mảng danh sách các database cần kiểm tra (format: "host:port:type:username:password:dbname")
# type: mysql hoặc postgres
DATABASES=(
    "192.168.1.206:9999:postgres:adempiere:adempiere:idempiere"  # Database 2 (PostgreSQL)
    "192.168.13.128:5432:postgres:adempiere:YGmm5bdy4bZHPJwADauOQiMxRby4NMyO:idempiere"  # Database 2 (PostgreSQL)
)

# Hàm gửi thông báo qua Telegram
send_telegram_message() {
    local message=$1
    echo "Sending Telegram message: $message"
    response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown")
    echo "Telegram response: $response"
}

# Kiểm tra kết nối với bot Telegram khi khởi động lần đầu
echo "Starting health check script at $(date '+%Y-%m-%d %H:%M:%S')"
FIRST_RUN_FILE="/app/.firstrun"
if [ ! -f "$FIRST_RUN_FILE" ]; then
    echo "First run detected, testing Telegram connection..."
    if curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="Test connection" > /dev/null 2>&1; then
        send_telegram_message "✅ *Bot check health idem đã được chạy vào lúc:* `date '+%Y-%m-%d %H:%M:%S'`"
        touch "$FIRST_RUN_FILE"  # Đánh dấu đã chạy lần đầu
        echo "First run completed, flag created."
    else
        echo "Lỗi: Không thể kết nối với Telegram API. Kiểm tra TELEGRAM_BOT_TOKEN và TELEGRAM_CHAT_ID."
    fi
fi

# Kiểm tra server bằng ping
for SERVER_HOST in "${SERVERS[@]}"; do
    echo "Pinging server $SERVER_HOST..."
    ping -c 4 "$SERVER_HOST" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        send_telegram_message "🚨 *Cảnh báo:* Server $SERVER_HOST không phản hồi (ping thất bại)!"
    else
        echo "Ping successful for $SERVER_HOST"
    fi
done

# Kiểm tra database bằng client
for DB in "${DATABASES[@]}"; do
    # Tách các trường từ chuỗi DB
    IFS=':' read -r DB_HOST DB_PORT DB_TYPE DB_USER DB_PASSWORD DBNAME <<< "$DB"
    
    echo "Checking database $DB_HOST:$DB_PORT ($DB_TYPE) with user $DB_USER..."
    if [ "$DB_TYPE" = "mysql" ]; then
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            send_telegram_message "🚨 *Cảnh báo:* Không thể kết nối đến database MySQL $DB_HOST:$DB_PORT!"
        else
            echo "Database MySQL $DB_HOST:$DB_PORT is reachable"
        fi
    elif [ "$DB_TYPE" = "postgres" ]; then
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DBNAME" -c "SELECT 1" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            send_telegram_message "🚨 *Cảnh báo:* Không thể kết nối đến database PostgreSQL $DB_HOST:$DB_PORT!"
        else
            echo "Database PostgreSQL $DB_HOST:$DB_PORT is reachable"
        fi
    else
        echo "Loại database $DB_TYPE không được hỗ trợ"
    fi
done

echo "Health check completed at $(date '+%Y-%m-%d %H:%M:%S')"