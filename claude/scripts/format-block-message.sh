#!/bin/bash
#ddev-generated
# format-block-message.sh - User-friendly firewall block notifications

SEEN_IPS="/tmp/ddev-claude-seen-blocks"
touch "$SEEN_IPS"

# Watch dmesg for new blocks
dmesg -w 2>/dev/null | while read -r line; do
    if [[ "$line" == *"[FIREWALL-BLOCK]"* ]]; then
        # Extract DST IP
        dst_ip=$(echo "$line" | sed -n 's/.*DST=\([0-9.]*\).*/\1/p')

        if [[ -z "$dst_ip" ]]; then
            continue
        fi

        # Skip if already seen recently (dedup)
        if grep -q "^$dst_ip$" "$SEEN_IPS" 2>/dev/null; then
            continue
        fi
        echo "$dst_ip" >> "$SEEN_IPS"

        # Reverse DNS lookup
        domain=$(dig +short -x "$dst_ip" +time=1 +tries=1 2>/dev/null | sed 's/\.$//' | head -1)

        # Output user-friendly message
        echo ""
        echo "[ddev-claude] Network request BLOCKED"
        if [[ -n "$domain" ]]; then
            echo "  Destination: $domain ($dst_ip)"
        else
            echo "  Destination: $dst_ip (unknown domain)"
        fi
        echo ""
        echo "  To allow this domain:"
        echo "  - Run: ddev claude:whitelist"
        echo "  - Or use Claude's /whitelist skill"
        echo ""
    fi
done
