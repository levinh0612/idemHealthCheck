FROM ubuntu:20.04

# Cài đặt các công cụ cần thiết
RUN apt-get update && apt-get install -y \
    curl \
    iputils-ping \
    mysql-client \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Sao chép script vào container và cấp quyền thực thi
COPY health_check.sh /app/health_check.sh
RUN chmod +x /app/health_check.sh

# Đặt thư mục làm việc
WORKDIR /app

# Đặt lệnh chạy mặc định
CMD ["bash", "-c", "while true; do /app/health_check.sh; sleep 900; done"]