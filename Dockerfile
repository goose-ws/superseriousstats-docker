FROM alpine:3.23

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    nginx \
    php \ 
    php-fpm \ 
    php-sqlite3 \ 
    php-ctype \ 
    php-curl \ 
    php-dom \ 
    php-mbstring \ 
    php-pdo \ 
    php-pdo_sqlite \ 
    php-session \ 
    php-zlib \ 
    sqlite \
    supervisor \
    su-exec \
    tzdata

# Create a non-root user
RUN addgroup -g 1000 sss
RUN adduser -u 1000 -G sss -D -h /app sss

WORKDIR /app

# 1. Clone the application
RUN git clone https://github.com/tommyrot/superseriousstats.git .
RUN rm -rf .git

# 2. Create directories
RUN mkdir -p /app/html /app/logs /app/db /app/config /run/php /run/nginx /var/lib/nginx/tmp /var/log/nginx /var/log/php
RUN chown -R sss:sss /app /run/php /run/nginx /var/lib/nginx /var/log/nginx /var/log/php

# Copy configuration files
COPY root/ /

# 3. Create the stats-loop script
COPY stats-loop.sh /usr/local/bin/stats-loop.sh
RUN chmod +x /usr/local/bin/stats-loop.sh

# Make entrypoint executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose HTTP port
EXPOSE 8080

# Define volumes
VOLUME ["/app/config", "/app/db", "/app/logs", "/app/html"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor.d/supervisord.ini"]