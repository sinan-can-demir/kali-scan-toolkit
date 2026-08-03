#!/bin/bash

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ..."
    exit 0
fi

if [[ -z "$1" ]]; then
    ARP_TARGET="--localnet"
else
    ARP_TARGET="$1"
fi


SAFE_TARGET="${ARP_TARGET//\//_}"

# timestamp for logging
TS=$(date +%Y%m%d_%H%M%S)
OUTFILE="scan_${TS}_${SAFE_TARGET}.txt"

docker run --rm --network host --cap-add=NET_RAW --cap-add=NET_ADMIN -v ~/kali-data:/root/data:z kali-scan-tools bash -c "arp-scan $ARP_TARGET > /root/data/$OUTFILE"
