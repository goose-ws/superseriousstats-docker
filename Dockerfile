FROM alpine:3.23

# Install dependencies (Updated to php83)
RUN apk add --no-cache \
    bash \
    curl \
    git \
    nginx \
    php83 \
    php83-ctype \
    php83-curl \
    php83-dom \
    php83-fpm \
    php83-mbstring \
    php83-pdo \
    php83-pdo_sqlite \
    php83-session \
    php83-sqlite3 \
    php83-zlib \
    sqlite \
    supervisor \
    su-exec \
    tzdata

# Create a non-root user
RUN addgroup -g 1000 sss && \
    adduser -u 1000 -G sss -D -h /app sss

WORKDIR /app

# 1. Clone the application
RUN git clone https://github.com/tommyrot/superseriousstats.git . && \
    rm -rf .git

# 2. Create directories (Updated to php83)
RUN mkdir -p /app/html /app/logs /app/db /app/config /run/php /run/nginx /var/lib/nginx/tmp /var/log/nginx /var/log/php83 && \
    chown -R sss:sss /app /run/php /run/nginx /var/lib/nginx /var/log/nginx /var/log/php83

# Copy configuration files
COPY root/ /

# 3. Create the SMARTER stats-loop script
RUN printf '#!/bin/bash\n\
while true; do\n\
    echo "[Stats] Starting update cycle..."\n\
    \n\
    # 1. Sync Assets\n\
    cp /app/sss.css /app/html/ 2>/dev/null\n\
    cp /app/favicon.svg /app/html/ 2>/dev/null\n\
    if [ -d /app/userpics ]; then cp -r /app/userpics /app/html/; fi\n\
    \n\
    # 2. Prepare Auto-Index\n\
    INDEX_FILE="/app/html/index.html"\n\
    echo "<html><head><title>IRC Stats</title><link rel=\"stylesheet\" href=\"sss.css\"></head><body><div id=\"container\"><div class=\"info\"><h1>Available Channels</h1><ul>" > "$INDEX_FILE"\n\
    \n\
    # 3. Process Configs\n\
    for conf in /app/config/*.conf; do\n\
        [ -e "$conf" ] || continue\n\
        name=$(basename "$conf" .conf)\n\
        \n\
        # Parse custom logdir or default to name\n\
        custom_logdir=$(grep "^logdir" "$conf" | cut -d\" -f2)\n\
        if [ -n "$custom_logdir" ]; then\n\
            log_target="/app/logs/$custom_logdir"\n\
        else\n\
            log_target="/app/logs/$name"\n\
        fi\n\
        \n\
        if [ -d "$log_target" ]; then\n\
            echo "[Stats] Processing $name"\n\
            \n\
            # Add link to Index\n\
            echo "<li><a href=\"$name.html\">$name</a></li>" >> "$INDEX_FILE"\n\
            \n\
            # Auto-Init DB\n\
            db_path=$(grep "^database" "$conf" | cut -d\" -f2)\n\
            if [ -n "$db_path" ] && [ ! -f "$db_path" ]; then\n\
                echo "[Stats] Initializing DB: $db_path"\n\
                sqlite3 "$db_path" < /app/sqlite_schema.sql\n\
                chown sss:sss "$db_path" 2>/dev/null\n\
            fi\n\
            \n\
            # Run Generator (Updated to php83)\n\
            /usr/bin/php83 /app/sss.php -c "$conf" -i "$log_target" -o "/app/html/$name.html"\n\
        else\n\
            echo "[Stats] Skipping $name: Logs not found at $log_target"\n\
        fi\n\
    done\n\
    \n\
    # Close Index\n\
    echo "</ul><p>Last updated: $(date)</p></div></div></body></html>" >> "$INDEX_FILE"\n\
    chown sss:sss "$INDEX_FILE" 2>/dev/null\n\
    \n\
    echo "[Stats] Cycle complete. Sleeping for 1 hour."\n\
    sleep 3600\n\
done\n' > /usr/local/bin/stats-loop.sh && \
    chmod +x /usr/local/bin/stats-loop.sh

# Make entrypoint executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose HTTP port
EXPOSE 8080

# Define volumes
VOLUME ["/app/config", "/app/db", "/app/logs", "/app/html"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor.d/supervisord.ini"]