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
- [x] Set up basic folder structure
  - Restructured in Epoch 4 planning: each tool family gets its own subdirectory (Dockerfile + scripts together), rather than one flat root. Motivation: `scan-tools` (one-shot CLI scripts) and `defense/suricata` (a long-running daemon, different config needs) are different *kinds* of things and shouldn't share a build context. `data/` stays shared at the root since output is common across tools.
  ```
  kali_docker_setup/
  ├── scan-tools/
  │   ├── Dockerfile
  │   ├── .dockerignore
  │   └── scripts/
  ├── defense/
  │   └── suricata/      (added when Epoch 4 build work starts)
  ├── README.md
  ├── SCOPE.md
  ├── roadmap.md
  ├── data/               (gitignored, shared across tools)
  └── .github/workflows/
  ```

### Epic: Core Docker Image
- [x] Write `Dockerfile` based on `kalilinux/kali-rolling`
- [x] Pin base image to a specific tag/digest (avoid silent drift)
- [x] Install core tools: `nmap`, `netdiscover`, `arp-scan`, `tshark`
- [x] Decide on the Wireshark non-root capture group setting
  - Decision: leave it closed (default), no `debconf-set-selections` needed. The container always runs as root, so the non-root-capture mechanism (wireshark group + capabilities on `dumpcap`) has nothing to grant privilege to — enabling it would just add an unused capability-widening path. Revisit only if a non-root `USER` is ever introduced.
- [x] Build and test locally: `docker build -t kali-scan-tools scan-tools/` (path updated after the Epoch 4 subdirectory restructure — was `.` when the Dockerfile lived at repo root)
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
- [x] Optional: script to summarize/diff scans over time (what changed on the network since last scan)
  - `scripts/diff-scans.sh` — compares the two most recent `arp-sweep.sh --localnet` outputs (chosen over `scan-subnet.sh`: `arp-scan`'s output is simpler to parse and more reliable, since every device must answer ARP to function on the network at all). Extracts IPs via `grep -oE`, diffs sorted lists with `comm -13`/`comm -23` (new vs. gone), fed via process substitution. Handles zero-scans and single-scan-only edge cases explicitly.
- [x] Document how to clean up old scan data safely
  - Went beyond docs: `scripts/clean-up.sh` — wipes `~/kali-data/`, gated behind a `[y/N]` confirmation prompt, reports success/failure based on `rm`'s actual exit code rather than assuming it worked

---

## Epoch 3 — Maturity
Goal: make the repo maintainable and polished, then layer on optional capabilities as real needs arise.

### Epic: Automation & Quality
- [x] GitHub Action: build the Docker image on every push, catch breakage early
- [x] Optional: lint shell scripts with `shellcheck` in CI
- [x] Require `build` and `tests` checks to pass before merging to `main` (branch protection)
  - Configured via `gh api`: required status checks (`build`, `tests`, strict mode), 1 required PR review, `enforce_admins: false` so the repo owner can still override/merge directly when needed. Normal flow is now branch → PR → CI → merge instead of direct pushes to `main`.
- [x] Add versioned releases/tags as the toolkit stabilizes (`v0.1`, `v0.2`, …)
- [x] Expand `README.md` with usage examples and sample output
  - Uses generic/placeholder IPs and output rather than real scan results, since the repo is public — no reason to publish specifics about the home network used for testing

### Epic: Nice-to-Haves / Backlog
Opportunistic — pull items into scope only when there's a concrete need, not on a schedule.
- [ ] Add optional tools as needed: `masscan`, `nikto`, `hydra` (only if you have a real use case — avoid bloat)
- [ ] Simple HTML/Markdown report generator from scan output
- [ ] Scheduled scan option (cron inside container or host-level cron calling `docker run`)
- [ ] Shodan/VirusTotal API integration for external recon (own domains only) — secrets via `.env`, never committed
- [ ] Multi-arch build support if you ever run this on ARM (Raspberry Pi)

---

## Epoch 4 — Defense Layer
Goal: add passive network intrusion detection alongside the existing active-scanning toolkit — watch traffic instead of just probing it.

### Epic: Network Intrusion Detection (Suricata)
Suricata over Snort: actively maintained, available directly in Kali's repos, supports the free Emerging Threats Open ruleset, and its `eve.json` alert log is JSON — much easier to script against than older text log formats.

- [x] Decide: separate image from `kali-scan-tools`, in its own `defense/suricata/` subdirectory (repo restructured for this — see Epoch 1's folder structure note)
- [ ] **Decide the container lifecycle model**: everything built in Epoch 2 is ephemeral (`docker run --rm`, scan, exit). An IDS needs to run continuously in the background instead — this is a new pattern (detached/long-running containers) to learn before writing any scripts here
- [ ] Configure Suricata to monitor the host's live interface (`--network host`, same requirement as the scanning scripts, but now for a sustained process instead of a one-shot run)
- [ ] Pull in the Emerging Threats Open ruleset (free community detection rules)
- [ ] Decide where alerts get written/persisted — likely `eve.json` into the existing `~/kali-data` mount, but as an append-only ongoing log rather than one file per run (different shape from the Epoch 2 output convention)
- [ ] Write a wrapper script to start/stop/check status of the IDS container (start/stop is a new kind of script — not "run once," but "manage a running thing")
- [ ] Document how to view/tail live alerts

### Epic: Future Defensive Capabilities (Backlog)
Ideas, not yet designed — promote one to a full epic (like Suricata above) only once you're ready to actually scope it. Not adding full checklists for these prematurely; each has real architecture questions of its own to work through first.
- [ ] Host/log monitoring (`fail2ban`, `auditd`) — reacts to suspicious local activity like repeated failed logins; likely the next one worth promoting, since it directly covers unauthorized-access attempts regardless of what's behind them
- [ ] Vulnerability/hardening audits (`Lynis`, `rkhunter`) — scans a system's own config for weaknesses, closer in spirit to the existing recon scripts (one-shot, not a daemon)
- [ ] Malware scanning (`ClamAV`) — on-demand scanning of files/downloads for known malware signatures

---

## Guiding Principles Throughout
- **Reproducible over convenient** — prefer Dockerfile changes over manual `apt install` inside a running container.
- **Data stays out of git** — scan results, pcaps, and logs live in a gitignored volume, not the repo.
- **Scope stays explicit** — every script and the README reinforce "your own network only."
- **Small and auditable** — resist scope creep; add tools only when you have a concrete need. Extends to structure, not just features: each tool family gets its own subdirectory with its own Dockerfile, so a different kind of tool (a daemon vs. a one-shot script) never has to share a build context with something it has nothing in common with.

---

## Epoch Exit Criteria
| Epoch | Deliverable |
|---|---|
| Epoch 1 — Foundation | Repo scaffolded, authorization docs in place, Dockerfile builds and runs core tools with `--network host` |
| Epoch 2 — Build-Out | Working scan scripts with standardized `--help`/params, persistent volume flow with a clear naming convention |
| Epoch 3 — Maturity | CI building the image on every push, polished README, first tagged release (`v0.1`) |
| Epoch 4 — Defense Layer | Suricata running as a long-lived container, watching live traffic, alerts viewable via a wrapper script |
