#!/bin/bash

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ..."
    exit 0
fi

read -rp "Delete all files in ~/kali-data? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted"
    exit 0
fi

if rm -f ~/kali-data/*; then
    echo "Deleted successfully"
else
    echo "Could not delete"
fi