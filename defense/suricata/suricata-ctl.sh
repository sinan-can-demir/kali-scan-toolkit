#!/bin/bash

case "$1" in
    start)
        echo "starting..."
        docker run -d \
        --name suricata-ids \
        --restart unless-stopped \
        --network host \
        --cap-add=NET_RAW \
        --cap-add=NET_ADMIN \
        -v ~/kali-data/suricata:/var/log/suricata:z \
        suricata-ids \
        suricata -c /etc/suricata/suricata.yaml -i wlp0s20f3
        ;;
    stop)
        echo "stopping..."
        docker stop suricata-ids
        docker rm suricata-ids
        ;;
    status)
        echo "checking..."
        docker ps --filter name=suricata-ids
        ;;
    logs)
        tail -f ~/kali-data/suricata/eve.json | jq 'select(.event_type == "alert")'
        ;;
    *)
        echo "Usage: $0 {start|stop|status} [interface]"
        exit 1
        ;;
esac