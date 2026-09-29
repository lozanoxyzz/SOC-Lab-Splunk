#!/bin/bash
# Splunk alert action: shut down the switch port of an internal attacker
# Flow: attacker IP -> MAC (pfSense ARP table) -> port (switch MAC table) -> shutdown
# Switch password is read from the SWITCH_PASS environment variable

RESULTS_FILE="$8"
LOGFILE="/opt/splunk/var/log/splunk/block_port.log"
PFSENSE="10.10.3.1"
SWITCH="10.10.2.20"
SSH_KEY="/opt/splunk/.ssh/id_rsa"
SSH_OPTS="-i $SSH_KEY -oKexAlgorithms=+diffie-hellman-group14-sha1 -oHostKeyAlgorithms=+ssh-rsa -oStrictHostKeyChecking=no"

echo "[$(date)] block_port.sh started" >> "$LOGFILE"

if [ -z "$RESULTS_FILE" ] || [ ! -f "$RESULTS_FILE" ]; then
    echo "[$(date)] ERROR: results file not found" >> "$LOGFILE"
    exit 1
fi

IPS=$(zcat "$RESULTS_FILE" | tail -n +2 | cut -d',' -f1 | tr -d '"' | sort -u)

for IP in $IPS; do
    echo "[$(date)] Processing IP: $IP" >> "$LOGFILE"

    # 1. MAC address from the pfSense ARP table
    MAC=$(ssh $SSH_OPTS admin@$PFSENSE "arp -a | grep $IP" | awk '{print $4}' | head -1)
    if [ -z "$MAC" ]; then
        echo "[$(date)] No MAC found for $IP" >> "$LOGFILE"
        continue
    fi

    # 2. Convert xx:xx:xx:xx:xx:xx to Cisco format xxxx.xxxx.xxxx
    MAC_CISCO=$(echo "$MAC" | awk -F: '{printf "%s%s.%s%s.%s%s\n", $1,$2,$3,$4,$5,$6}')
    echo "[$(date)] MAC found: $MAC_CISCO" >> "$LOGFILE"

    # 3. Switch port from the MAC address table
    PORT=$(sshpass -p "$SWITCH_PASS" ssh $SSH_OPTS admin@$SWITCH \
        "show mac address-table address $MAC_CISCO" | grep DYNAMIC | awk '{print $4}')
    if [ -z "$PORT" ]; then
        echo "[$(date)] No port found for MAC $MAC_CISCO" >> "$LOGFILE"
        continue
    fi
    echo "[$(date)] Port found: $PORT" >> "$LOGFILE"

    # 4. Shut the port down
    /opt/splunk/bin/scripts/shutdown_port.expect "$SWITCH" "$PORT" "$SWITCH_PASS"
    echo "[$(date)] Port $PORT shut down for IP $IP" >> "$LOGFILE"
done

echo "[$(date)] block_port.sh finished" >> "$LOGFILE"
