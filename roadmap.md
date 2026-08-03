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
- [ ] Decide on the Wireshark non-root capture group setting (bake the `yes`/`no` choice into the Dockerfile non-interactively via `debconf-set-selections`)
- [x] Build and test locally: `docker build -t kali-scan-tools .`
- [x] Confirm `--network host` scanning works as expected on your host
  - Note: this daemon doesn't grant `nmap` raw-socket access by default — containers must be run with `--cap-add=NET_RAW --cap-add=NET_ADMIN`. Bake this into Epoch 2's scripts and document it in the README.

---

## Epoch 2 — Build-Out
Goal: turn the base image into a usable toolkit — repeatable scripts plus persistent, well-organized output.

### Epic: Scripting Layer
- [ ] `scripts/scan-subnet.sh` — host discovery (`nmap -sn`)
- [ ] `scripts/quick-recon.sh` — port + service scan on a given host
- [ ] `scripts/arp-sweep.sh` — ARP-based discovery (host networking only)
- [ ] Standardize output: timestamped filenames, saved to `data/`
- [ ] Add a simple `--help` / usage message to each script
- [ ] Parameterize target subnet (no hardcoded IPs) via CLI arg or `.env`

### Epic: Data & Persistence
- [ ] Standardize volume mount: `-v ~/kali-data:/root/data`
- [ ] Decide naming convention for scan output (e.g. `scan_YYYYMMDD_HHMM_target.txt`)
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
