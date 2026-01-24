#!/bin/bash
while true; do
    echo "[Stats] Starting update cycle..."

    cp /app/sss.css /app/html/ 2>/dev/null
    cp /app/favicon.svg /app/html/ 2>/dev/null
    if [ -d /app/userpics ]; then cp -r /app/userpics /app/html/; fi

    INDEX_FILE="/app/html/index.html"
    echo "<html><head><title>IRC Stats</title><link rel=\"stylesheet\" href=\"sss.css\"></head><body><div id=\"container\"><div class=\"info\"><h1>Available Channels</h1><ul>" > "$INDEX_FILE"

    for conf in /app/config/*.conf; do
        [ -e "$conf" ] || continue
        name=$(basename "$conf" .conf)

        custom_logdir=$(grep "^logdir" "$conf" | cut -d\" -f2)
        if [ -n "$custom_logdir" ]; then
            log_target="/app/logs/$custom_logdir"
        else
            log_target="/app/logs/$name"
        fi

        if [ -d "$log_target" ]; then
            echo "[Stats] Processing $name"

            echo "<li><a href=\"$name.html\">$name</a></li>" >> "$INDEX_FILE"

            db_path=$(grep "^database" "$conf" | cut -d\" -f2)
            if [ -n "$db_path" ] && [ ! -f "$db_path" ]; then
                echo "[Stats] Initializing DB: $db_path"
                sqlite3 "$db_path" < /app/sqlite_schema.sql
                chown sss:sss "$db_path" 2>/dev/null
            fi

            /usr/bin/php /app/sss.php -c "$conf" -i "$log_target" -o "/app/html/$name.html"
        else
            echo "[Stats] Skipping $name: Logs not found at $log_target"
        fi
    done

    echo "</ul><p>Last updated: $(date)</p></div></div></body></html>" >> "$INDEX_FILE"
    chown sss:sss "$INDEX_FILE" 2>/dev/null

    echo "[Stats] Cycle complete. Sleeping for 1 hour."
    sleep 3600
done

