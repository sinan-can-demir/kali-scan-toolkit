# Kali Scan Tools — Project Roadmap

A personal network-scanning toolkit built on Docker + Kali Linux, for authorized use on networks you own or control.

---

## Epoch 1 — Foundation
Goal: get the repo skeleton, authorization posture, and a reproducible base image in place before writing any scan logic.

### Epic: Repo & Governance
- [x] Create GitHub repo (`kali-scan-tools`), choose private/public
- [x] Add `README.md` with project purpose and tool list
- [x] Add `SCOPE.md` — explicit statement of authorized use (your own network/devices only)
- [x] Add `LICENSE` (MIT/Apache 2.0)
- [x] Add `.gitignore` / `.dockerignore` (exclude scan results, pcaps, logs, `.env`)
- [x] Set up basic folder structure:
  ```
  kali-scan-tools/
  ├── Dockerfile
  ├── README.md
  ├── SCOPE.md
  ├── scripts/
  ├── data/        (gitignored)
  └── .github/workflows/
  ```

### Epic: Core Docker Image
- [x] Write `Dockerfile` based on `kalilinux/kali-rolling`
- [x] Pin base image to a specific tag/digest (avoid silent drift)
- [x] Install core tools: `nmap`, `netdiscover`, `arp-scan`, `tshark`
- [x] Decide on the Wireshark non-root capture group setting
  - Decision: leave it closed (default), no `debconf-set-selections` needed. The container always runs as root, so the non-root-capture mechanism (wireshark group + capabilities on `dumpcap`) has nothing to grant privilege to — enabling it would just add an unused capability-widening path. Revisit only if a non-root `USER` is ever introduced.
- [x] Build and test locally: `docker build -t kali-scan-tools .`
- [x] Confirm `--network host` scanning works as expected on your host
  - Note: this daemon doesn't grant `nmap` raw-socket access by default — containers must be run with `--cap-add=NET_RAW --cap-add=NET_ADMIN`. Bake this into Epoch 2's scripts and document it in the README.

---

## Epoch 2 — Build-Out
Goal: turn the base image into a usable toolkit — repeatable scripts plus persistent, well-organized output.

### Epic: Scripting Layer
- [x] `scripts/scan-subnet.sh` — host discovery (`nmap -sn`)
- [x] `scripts/quick-recon.sh` — port + service scan on a given host (`nmap -sV -T4 -sC -Pn`; required-target validation instead of a default, since a single host has no sane fallback)
- [x] `scripts/arp-sweep.sh` — ARP-based discovery (host networking only; `arp-scan`, optional target defaulting to `--localnet`, output redirected via `bash -c` since `arp-scan` has no native `-oN`-style flag)
- [x] Standardize output: timestamped filenames, saved to `data/`
  - Convention landed in `scan-subnet.sh`: `scan_<TS>_<sanitized-target>.txt`, written via `nmap -oN` into a `-v ~/kali-data:/root/data:z` mount. On SELinux hosts (Fedora et al.) the mount needs the `:z` label or writes fail with `Permission denied` — harmless no-op on non-SELinux systems, so keep it in every script.
- [x] Add a simple `--help` / usage message to each script (flesh out the placeholder text as scripts are written)
- [x] Parameterize target subnet (no hardcoded IPs) via CLI arg or `.env`
  - Pattern: `TARGET="${1:-192.168.1.0/24}"` — CLI arg with a sane default

### Epic: Data & Persistence
- [x] Standardize volume mount: `-v ~/kali-data:/root/data:z` (both scripts share this; `:z` label required on SELinux hosts)
- [x] Decide naming convention for scan output: `scan_<timestamp>_<sanitized-target>.txt`, e.g. `scan_20260803_060700_192.168.1.254.txt`
- [ ] Optional: script to summarize/diff scans over time (what changed on the network since last scan)
- [ ] Document how to clean up old scan data safely

---

## Epoch 3 — Maturity
Goal: make the repo maintainable and polished, then layer on optional capabilities as real needs arise.

### Epic: Automation & Quality
- [ ] GitHub Action: build the Docker image on every push, catch breakage early
- [ ] Optional: lint shell scripts with `shellcheck` in CI
- [ ] Add versioned releases/tags as the toolkit stabilizes (`v0.1`, `v0.2`, …)
- [ ] Expand `README.md` with usage examples and sample output

### Epic: Nice-to-Haves / Backlog
Opportunistic — pull items into scope only when there's a concrete need, not on a schedule.
- [ ] Add optional tools as needed: `masscan`, `nikto`, `hydra` (only if you have a real use case — avoid bloat)
- [ ] Simple HTML/Markdown report generator from scan output
- [ ] Scheduled scan option (cron inside container or host-level cron calling `docker run`)
- [ ] Shodan/VirusTotal API integration for external recon (own domains only) — secrets via `.env`, never committed
- [ ] Multi-arch build support if you ever run this on ARM (Raspberry Pi)

---

## Guiding Principles Throughout
- **Reproducible over convenient** — prefer Dockerfile changes over manual `apt install` inside a running container.
- **Data stays out of git** — scan results, pcaps, and logs live in a gitignored volume, not the repo.
- **Scope stays explicit** — every script and the README reinforce "your own network only."
- **Small and auditable** — resist scope creep; add tools only when you have a concrete need.

---

## Epoch Exit Criteria
| Epoch | Deliverable |
|---|---|
| Epoch 1 — Foundation | Repo scaffolded, authorization docs in place, Dockerfile builds and runs core tools with `--network host` |
| Epoch 2 — Build-Out | Working scan scripts with standardized `--help`/params, persistent volume flow with a clear naming convention |
| Epoch 3 — Maturity | CI building the image on every push, polished README, first tagged release (`v0.1`) |
