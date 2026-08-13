# select kali image
FROM kalilinux/kali-rolling@sha256:3093a0bd1f1196f4b10ab8e4a671929a6cd0153768642e6aa20dfced5e4132c5

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y nmap netdiscover arp-scan tshark testssl.sh && rm -rf /var/lib/apt/lists/*

WORKDIR /root

COPY scripts/ /usr/local/bin/

CMD ["/bin/bash"]