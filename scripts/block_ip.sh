#!/bin/bash
# Splunk alert action: block attacker IPs on pfSense
# Splunk passes the path of the gzipped results CSV as argument $8

RESULTS_FILE="$8"
PFSENSE_HOST="10.10.3.1"
SSH_KEY="/opt/splunk/.ssh/id_rsa"
LOGFILE="/opt/splunk/var/log/splunk/block_ip.log"

echo "[$(date)] Alert triggered" >> "$LOGFILE"

# Extract unique source IPs (first column of the results)
gunzip -c "$RESULTS_FILE" | awk -F',' 'NR>1 {gsub(/"/,"",$1); print $1}' | sort -u | while read -r IP; do
    if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "[$(date)] Blocking $IP" >> "$LOGFILE"
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no admin@"$PFSENSE_HOST" \
            "pfctl -t BLOCKED_IPS -T add $IP" >> "$LOGFILE" 2>&1
    fi
done
