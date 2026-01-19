# SuperSeriousStats - Docker

This is an unofficial, self-contained Docker image for [SuperSeriousStats](https://github.com/tommyrot/superseriousstats) by tommyrot.

It packages the PHP parser, Nginx web server, and a smart, multi-channel scheduler into a single, lightweight Alpine container.

## Features

* **Multi-Channel Support:** Automatically detects and updates statistics for multiple channels from a single container.
* **Self-Contained:** Includes Nginx to serve the generated stats immediately on port `8080`.
* **Smart Scheduling:** Watches your config directory and updates every channel defined therein once per hour.
* **Auto-Index:** Automatically generates a dashboard (`index.html`) listing all available channels.
* **Self Updating:** The container image automatically rebuilds whenever the upstream repository is updated.

## Prerequisites

### 1. Log Directory Structure

**Requirement:** `superseriousstats` aggregates *all* logs found in a target directory into a single dataset.
**Implication:** You **must** isolate every channel into its own subdirectory. Do not mix logs from different channels in the same folder, or their statistics will be merged.

**Recommended Structure:**

```text
/logs
├── snoonet/
│   └── #atlanta/   <-- Point atlanta.conf 'logdir' here
│       ├── #atlanta.2025-01-18.log
│       └── ...
└── freenode/
    └── #linux/     <-- Point linux.conf 'logdir' here
        ├── #linux.2025-01-18.log
        └── ...

```

### 2. Log Filename Format

**Requirement:** The upstream parser **ignores** any file that does not contain a date in the filename.

* **Supported:** `channel.2025-01-18.log`, `20250118.log`
* **Unsupported:** `channel.log` (Monolithic files are ignored)

## Quick Start

### 1. Directory Setup

Create folders on your host to store configuration and data:

```bash
mkdir -p sss/{config,db,html}

```

### 2. Docker Compose

Create a `docker-compose.yaml`:

```yaml
services:
  stats:
    image: ghcr.io/goose-ws/superseriousstats-docker:latest
    container_name: sss
    hostname: sss
    ports:
      - "8080:8080" # If not reverse proxying
    volumes:
      # 1. Mount your ENTIRE logs directory (Read-Only recommended)
      - /home/user/.weechat/logs:/app/logs:ro
      # 2. Configuration files (One .conf per channel)
      - ./sss/config:/app/config
      # 3. Persistent Database Storage
      - ./sss/db:/app/db
      # 4. Generated HTML Output
      - ./sss/html:/app/html
      # Timezone
      - "/etc/timezone:/etc/timezone:ro"
      - "/etc/localtime:/etc/localtime:ro"
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-file: "1"
        max-size: "10M"
```

### 3. Channel Configuration

Create a `.conf` file in your `config/` directory for **each channel** you want to track.

**Example:** `docker/sss/config/atlanta.conf`

```ini
# --- Required Settings ---
channel = "#Atlanta"
parser = "weechat"  # Options: irssi, weechat, znc, eggdrop, textual, etc.
timezone = "America/New_York"

# Database Path (Must be unique per channel)
database = "/app/db/atlanta.db"

# --- Docker Mapping Setting ---
# Tells the container specifically where to look inside /app/logs
logdir = "snoonet/#atlanta"

# --- Optional Tweaks ---
auto_link_nicks = "true"
link_user_php = "false"     # Disable dynamic links (recommended for multi-channel)
link_history_php = "false"

```

### 4. Run It

```bash
docker compose up -d

```

Access your stats at **http://localhost:8080**. You will see an index listing all configured channels.

## How it Works (Under the Hood)

The container runs a loop script (`stats-loop.sh`) that iterates over every `.conf` file found in `/app/config`.

For each configuration file, it constructs and executes the standard `sss.php` command:

```bash
php sss.php -c <config_file> -i <log_directory> -o <html_output>

```

### Command Options Explained

* **`-c <file>`**: The configuration file to use (e.g., `/app/config/atlanta.conf`).
* **`-i <directory>`**: The input directory containing the logs. The script determines this path using the `logdir` variable in your config file (relative to `/app/logs`).
* **`-o <file>`**: The output HTML file path (e.g., `/app/html/atlanta.html`).
* **`-q`**: Quiet mode (suppresses output).
* **`-v`**: Verbose mode (useful for debugging parser issues).

If you need to debug a specific channel manually, you can enter the container and run this command yourself:

```bash
docker exec -it sss /bin/bash
# Inside the container:
php sss.php -v -c /app/config/atlanta.conf -i /app/logs/snoonet/#atlanta -o /app/html/test.html

```

## Reverse Proxy Configuration

You likely want to put this container behind your main Nginx or Apache load balancer.

### Option A: Subdomain (https://stats.example.com)

This is the simplest method.

```nginx
server {
    server_name stats.example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

```

### Option B: Subdirectory (https://example.com/stats/)

Use this if you want to host the stats under a path.
**Note:** The trailing slash in `proxy_pass` is critical. It strips the `/stats/` prefix before sending the request to the container.

```nginx
location /stats/ {
    # 1. The trailing slash after 8080 is REQUIRED.
    #    It turns "example.com/stats/atlanta.html" -> "/atlanta.html"
    proxy_pass http://localhost:8080/;
    
    # 2. Standard Headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

```

## Advanced Usage

### The `logdir` Parameter

This Docker image adds a custom parameter to the config file: `logdir`.

* It specifies the subdirectory relative to `/app/logs` where the parser should look.
* **Example:** If your logs are mounted to `/app/logs` and your target logs are in `/app/logs/freenode/#linux`, you set:
```ini
logdir = "freenode/#linux"

```


* *If omitted, the script assumes the folder name matches the config filename (e.g., `linux.conf` -> `/app/logs/linux`).*

### Custom Assets

To use custom CSS or images, simply place them in the root of the container (via a mount) or modify the source. The container automatically copies `sss.css`, `favicon.svg`, and the `userpics/` directory to the output folder every hour.

### User & History Pages

The static HTML generation works perfectly for multiple channels. However, the dynamic PHP scripts (`user.php`, `history.php`) rely on a single default database configuration (`sss.conf`).

* **Limitation:** Clicking a username to view detailed history may not work correctly in a multi-channel setup, as the script may look in the wrong database.
* **Workaround:** Set `link_user_php = "false"` and `link_history_php = "false"` in your config files to disable these links.

## Troubleshooting

**"No logfiles found having a date in their name"**

* Ensure your log filenames contain `YYYY-MM-DD`.
* Ensure your `logdir` path in the `.conf` file matches the folder structure inside `/app/logs`.
* Check inside the container: `docker exec -it sss ls -la /app/logs`

**"Permission Denied"**

* The container attempts to fix permissions on `/app/db` and `/app/html` automatically on startup.
* Ensure the host user has read permissions on the log directory.

## License & Credits

**SuperSeriousStats** is developed by **Jos de Ruijter** and is licensed under the ISC License.

This Docker wrapper is licensed under the **MIT License**.

* Upstream Repository: [https://github.com/tommyrot/superseriousstats](https://github.com/tommyrot/superseriousstats)
* Docker Maintainer: goose-ws