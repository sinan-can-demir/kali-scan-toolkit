# Kali Scan Tools

A personal network-scanning toolkit built on Docker + Kali Linux — for use only on networks and devices you own or have explicit permission to test. See [SCOPE.md](SCOPE.md) for the full authorized-use statement before running anything here.

## ⚠️ Authorized use only

These tools perform active and passive network reconnaissance (host discovery, port scanning, service detection, ARP sweeps). Only run them against:

- Networks and devices **you own**
- Networks and devices you have **explicit, documented permission** to test

Scanning any network or device you do not own or have permission to test may be **illegal**, regardless of intent. You are solely responsible for ensuring you have the right to scan any target before using these tools. See [SCOPE.md](SCOPE.md) for the full policy.

## What's inside

A Kali-based Docker image (`scan-tools/`) with:

- [`nmap`](https://nmap.org/) — host discovery, port + service scanning
- [`arp-scan`](https://github.com/royhills/arp-scan) — ARP-based local network discovery
- [`netdiscover`](https://github.com/netdiscover-scanner/netdiscover) — passive/active ARP reconnaissance
- [`tshark`](https://www.wireshark.org/docs/man-pages/tshark.html) — packet capture (Wireshark's CLI)
- [`testssl.sh`](https://testssl.sh/) — TLS/SSL configuration auditing (protocols, ciphers, certificate validity, known vulnerabilities)

...wrapped in scripts (`scan-tools/scripts/`) that handle the Docker invocation, output persistence, and safe defaults for you.

## Prerequisites

- Docker
- Linux host (scripts rely on `--network host` for raw network access — this won't work the same way on Docker Desktop for Mac/Windows, which runs containers inside a VM)
- On SELinux-enforcing systems (Fedora, RHEL, etc.), no extra setup needed — the scripts already include the `:z` volume label required for container writes to succeed

## Build the image

```bash
docker build -t kali-scan-tools scan-tools/
```

## Usage

Each script handles its own `docker run` invocation — including the `--cap-add=NET_RAW --cap-add=NET_ADMIN` flags required for raw-socket scanning, and the `-v ~/kali-data:/root/data:z` mount for persisting output. You don't need to touch Docker directly.

### `scan-subnet.sh` — host discovery

Finds live hosts on a subnet via `nmap -sn` (ping sweep).

```bash
./scan-tools/scripts/scan-subnet.sh 192.168.1.0/24
```
Defaults to `192.168.1.0/24` if no argument is given.

```
Starting Nmap 7.99 ( https://nmap.org )
Nmap scan report for 192.168.1.1
Host is up (0.0021s latency).
Nmap scan report for 192.168.1.42
Host is up (0.0087s latency).
Nmap done: 256 IP addresses (2 hosts up) scanned in 2.41 seconds
```

### `quick-recon.sh` — port + service scan on one host

Runs `nmap -sV -T4 -sC -Pn` against a specific target — service/version detection plus default NSE scripts, skipping the host-liveness check.

```bash
./scan-tools/scripts/quick-recon.sh 192.168.1.1
```
Target is required — there's no sensible default for a single host.

```
PORT    STATE SERVICE  VERSION
22/tcp  open  ssh      OpenSSH 9.6
80/tcp  open  http     lighttpd 1.4.69
443/tcp open  ssl/http lighttpd 1.4.69
```

### `arp-sweep.sh` — ARP-based local discovery

Uses `arp-scan` directly instead of `nmap` — more reliable on a local segment since every device has to answer ARP to function on the network at all, unlike ICMP/TCP probes which firewalls can silently drop.

```bash
./scan-tools/scripts/arp-sweep.sh          # sweeps your local network automatically
./scan-tools/scripts/arp-sweep.sh eth0     # optional: target a specific interface
```

```
192.168.1.1     aa:bb:cc:dd:ee:ff    Some Router Vendor
192.168.1.42    11:22:33:44:55:66    Some Device Vendor
```

### `testssl.sh` — TLS/SSL configuration audit

Runs `testssl` against a single target, checking protocol versions, cipher strength, certificate validity, and known TLS vulnerabilities (Heartbleed, POODLE, etc.). Unlike the other scripts, this one doesn't need `--cap-add=NET_RAW`/`NET_ADMIN` — it's a standard TLS client, not raw-socket tooling.

```bash
./scan-tools/scripts/testssl.sh 192.168.1.1
```
Target is required — there's no sensible default for a single host.

```
Certificate Validity (UTC)   expired (2015-06-01 --> 2025-05-29)
Chain of trust               NOT ok (self signed)
Trust (hostname)             certificate does not match supplied URI
TLS 1.2                      offered (OK)
TLS 1.3                      offered (OK): final
Overall Grade                T
```

### `clean-up.sh` — wipe saved scan data

Deletes everything in `~/kali-data/`, gated behind a confirmation prompt.

```bash
./scan-tools/scripts/clean-up.sh
```
```
Delete all files in ~/kali-data? [y/N] y
Deleted successfully
```

All scripts support `-h` / `--help` for a usage reminder.

## Output

Scan results are saved to `~/kali-data/` on your host, timestamped and named after their target:
```
scan_20260803_060700_192.168.1.0_24.txt
```
This directory is gitignored — scan data never ends up in version control.

## Development

- CI (`.github/workflows/ci.yml`) builds the Docker image and lints all scripts with `shellcheck` on every push and pull request.
- `main` is protected — changes go through a branch + pull request, gated on CI passing.
- Tagged releases (`v0.1`, `v0.2`, ...) are published automatically via `.github/workflows/release.yml` when a `v*` tag is pushed.

See [roadmap.md](roadmap.md) for full project history and what's planned next.

## License

[MIT](LICENSE)
