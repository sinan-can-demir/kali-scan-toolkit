#!/bin/bash

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ..."
    exit 0
fi

TARGET="${1:-192.168.1.0/24}"
SAFE_TARGET="${TARGET//\//_}"

# timestamp for logging
TS=$(date +%Y%m%d_%H%M%S)
OUTFILE="scan_${TS}_${SAFE_TARGET}.txt"

# make sure data host data directory exists
mkdir -p ~/kali-data

# runs the docker to scan the target
docker run --rm --network host --cap-add=NET_RAW --cap-add=NET_ADMIN -v ~/kali-data:/root/data:z kali-scan-tools nmap -sn -oN "/root/data/$OUTFILE" "$TARGET"

