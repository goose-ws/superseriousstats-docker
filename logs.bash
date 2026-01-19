cd /home/goose/weechat-logs

# 1. Backup existing files just in case
mkdir -p _backup
cp irc.*.weechatlog _backup/ 2>/dev/null

# 2. Process every log file
for file in irc.*.weechatlog; do
    [ -e "$file" ] || continue

    # Extract Network (e.g., "snoonet" from "irc.snoonet.#atlanta...")
    network=$(echo "$file" | cut -d. -f2)

    # Extract Channel (e.g., "#atlanta")
    # We use sed to reliably strip the prefix "irc.network." and suffix ".weechatlog"
    channel=$(echo "$file" | sed -e "s/^irc\.$network\.//" -e 's/\.weechatlog$//')

    # 3. Create the drilled-down directory: snoonet/#atlanta
    target_dir="$network/$channel"
    mkdir -p "$target_dir"

    echo "Processing $network / $channel..."

    # 4. Split monolithic file into daily logs inside that specific folder
    # Result: snoonet/#atlanta/#atlanta.2025-01-18.log
    awk -v out_dir="$target_dir" -v fname="$channel" '{ 
        # Output file: directory/channel.date.log
        outfile = out_dir "/" fname "." $1 ".log"; 
        print >> outfile; 
        close(outfile);
    }' "$file"
done

echo "Migration complete. You now have a deep directory structure."
