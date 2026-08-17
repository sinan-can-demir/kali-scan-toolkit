#!/bin/bash

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ./nikto.sh <target> or sh nikto.sh <target>"
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "Usage: ./nikto.sh <target> or sh nikto.sh"
    exit 1
fi

TARGET="$1"
SAFE_TARGET="${TARGET//\//_}"

# timestamp for logging
TS=$(date +%Y%m%d_%H%M%S)
OUTFILE="scan_${TS}_${SAFE_TARGET}"

docker run --rm -v ~/kali-data:/root/data:z kali-scan-tools nikto -h "$TARGET" -output "/root/data/$OUTFILE" -Format txt