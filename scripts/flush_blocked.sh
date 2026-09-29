#!/bin/bash
# Clears the BLOCKED_IPS table on pfSense to reset the lab between demos

echo "[*] Flushing BLOCKED_IPS on pfSense..."
ssh -i /opt/splunk/.ssh/id_rsa admin@10.10.3.1 "pfctl -t BLOCKED_IPS -T flush"
echo "[*] Done."
