#!/bin/bash

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ..."
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "Usage: ..."
    exit 1
fi

TARGET="$1"
SAFE_TARGET="${TARGET//\//_}"

# timestamp for logging
TS=$(date +%Y%m%d_%H%M%S)
OUTFILE="scan_${TS}_${SAFE_TARGET}.txt"

docker run --rm --network host --cap-add=NET_RAW --cap-add=NET_ADMIN -v ~/kali-data:/root/data:z kali-scan-tools nmap -sV -T4 -sC -Pn -oN "/root/data/$OUTFILE" "$TARGET"
