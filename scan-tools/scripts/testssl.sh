#!/bin/bash

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: testssl.sh <target>"
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "Usage: testssl.sh <target>"
    exit 1
fi

TARGET="$1"
SAFE_TARGET="${TARGET//\//_}"

# timestamp for logging
TS=$(date +%Y%m%d_%H%M%S)
OUTFILE="scan_${TS}_${SAFE_TARGET}.txt"

docker run --rm --network host -v ~/kali-data:/root/data:z kali-scan-tools testssl -oL "/root/data/$OUTFILE" "$TARGET"
