#!/bin/bash
set -e

# --- PERMISSION FIX START ---
echo "Fixing permissions..."

# Directories that need to be writable by 'sss'
# We check and chown them to ensure the services can start
for dir in /app/db /app/html /app/config /run/php /run/nginx /var/lib/nginx /var/log/nginx /var/log/php83; do
    if [[ -d "$dir" ]]; then
        chown -R sss:sss "$dir"
    fi
done

# Note: We do NOT chown /app/logs because it is likely read-only
# --- PERMISSION FIX END ---

# Only generate a default config if the /app/config directory is essentially empty
DEFAULT_CONF="/app/config/default.conf"
if ! ls /app/config/*.conf >/dev/null 2>&1; then
    echo "No config files found. Generating default.conf..."
    
    cat <<EOF > "${DEFAULT_CONF}"
channel = "${SSS_CHANNEL:-#test}"
parser = "${SSS_PARSER:-irssi}"
timezone = "${SSS_TIMEZONE:-UTC}"
database = "/app/db/stats.db"
auto_link_nicks = "true"
stylesheet = "sss.css"
link_history_php = "true"
link_user_php = "true"
main_page = "./"
userpics_dir = "userpics"
userpics_default = ""
show_banner = "true"
favicon = "favicon.svg"
xxl = "false"
EOF
    # Ensure the user can read/write the generated config
    chown sss:sss "${DEFAULT_CONF}"

    # Symlink logs for backward compatibility if needed
    if [[ ! -d "/app/logs/default" ]] && [[ -d "/app/logs" ]]; then
        ln -s /app/logs /app/logs/default 2>/dev/null || true
    fi
fi

# Update web.php path ONLY if we are in single-channel mode
if [[ -f "/app/db/stats.db" ]]; then
    if [[ -f "web.php" ]]; then
        sed -i "s|%CHANGEME%|/app/db/stats.db|g" web.php
    fi
fi

# Execute Supervisord as ROOT. 
# It will drop privileges for the individual services based on the .ini file.
echo "Starting Supervisord..."
exec "$@"