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

### Epic: Supply Chain Security (Image Scanning)
Different goal from the Lynis/rkhunter idea it grew out of — not auditing the host machine (a container can't meaningfully do that, same reasoning as `auditd`), but auditing the Docker images this project actually builds and ships: are `kali-scan-tools` and `suricata-ids` free of known-vulnerable packages?
- [ ] New `scan` job in `ci.yml`, using `aquasecurity/trivy-action` against both built images, filtered to `CRITICAL,HIGH` to avoid low-severity noise
- [ ] Deliberately **non-blocking** for now (`exit-code: 0`) — a scan job that fails the build over a CVE in an unrelated base-image package (discovered after the fact, not caused by any code change) would create surprise failures on trivial PRs. Report first, decide later — once there's a sense of what it actually flags in practice — whether to promote `scan` to a required branch-protection check.

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
- [x] **Decide the container lifecycle model**: `docker run -d` (detached) instead of `--rm`, named container (`--name suricata-ids`) so it can be managed after the fact via `docker logs`/`stop`/`start`. `--restart unless-stopped` planned for the wrapper script, so monitoring survives crashes/reboots without silently staying down.
- [x] Configure Suricata to monitor the host's live interface (`--network host`, same as the scanning scripts) — tested against the real interface (`wlp0s20f3`)
  - Same capability gotcha as `nmap`/`arp-scan`, different symptom: without `--cap-add=NET_RAW --cap-add=NET_ADMIN`, Suricata starts but spams `ioctl: ... Operation not permitted` (it can't configure NIC offload settings via `SIOCETHTOOL`). Confirmed fixed by adding both flags — warnings disappeared entirely on retest.
  - Interface name is **not** hardcoded into the Dockerfile/image — `CMD` in the Dockerfile is just a fallback; the real value gets supplied at `docker run` time (fully overrides `CMD`) via the upcoming wrapper script, same `${1:-default}` pattern as the other scripts. Keeps the image portable across machines/interfaces.
- [x] Pull in the Emerging Threats Open ruleset (free community detection rules)
  - `RUN suricata-update` in the Dockerfile, right after install — Suricata's own companion tool for rule management, defaults to Emerging Threats Open, writes to the exact path Suricata's config expects (`/var/lib/suricata/rules/suricata.rules`), and runs a config self-test (`suricata -T`) as part of the update. 68,186 rules loaded, 52,245 enabled. Baked in at build time — same reproducibility-vs-freshness tradeoff as the pinned base image digest; periodic rebuilds needed to keep rules current, not automated for now.
- [x] Decide where alerts get written/persisted
  - `-v ~/kali-data/suricata:/var/log/suricata:z` — mounts Suricata's default log directory as-is (`eve.json`, `fast.log`, `stats.log`, `suricata.log`), no `suricata.yaml` editing needed. Deliberately its own subdirectory, not mixed in with `~/kali-data`'s timestamped scan files — `eve.json` is a continuously-growing append-only log, a different shape from one-file-per-run.
  - Verified end-to-end with the full run command: `-d --restart unless-stopped --network host --cap-add=NET_RAW --cap-add=NET_ADMIN -v ...`. Clean `Engine started`, no `ioctl` warnings, all four log files present in the mounted directory.
- [x] Write a wrapper script to start/stop/check status of the IDS container
  - `defense/suricata/suricata-ctl.sh` — first script in the project with subcommands (`start`/`stop`/`status`) instead of a single job, dispatched via a bash `case` statement rather than the `if`/`elif` pattern used elsewhere. `stop` runs both `docker stop` and `docker rm` — without the `rm`, the next `start` would fail with a name-conflict error, since this container isn't run with `--rm`. `status` uses `docker ps --filter` for a readable one-line answer rather than the much noisier `docker inspect`. Verified: start → status → stop → start again (confirms no naming conflict) → stop, all correct.
- [x] Document how to view/tail live alerts
  - Fourth `suricata-ctl.sh` subcommand: `logs` — `tail -f ~/kali-data/suricata/eve.json | jq 'select(.event_type == "alert")'`. Raw `eve.json` is a firehose of routine `flow`/`stats` events (one per connection); the `jq` filter keeps only actual rule-based detections. Verified against real traffic: an early test caught a genuine alert (confirmed via `"alert":1` in the stats block) before the filter was added; after adding it, `logs` correctly shows nothing during quiet periods instead of noise, and would show just the alert JSON, pretty-printed, when one fires.

### Epic: Future Defensive Capabilities (Backlog)
Ideas, not yet designed — promote one to a full epic (like Suricata above) only once you're ready to actually scope it. Not adding full checklists for these prematurely; each has real architecture questions of its own to work through first.
- [ ] Vulnerability/hardening audits (`Lynis`, `rkhunter`) — scans a system's own config for weaknesses, closer in spirit to the existing recon scripts (one-shot, not a daemon)
- [ ] Malware scanning (`ClamAV`) — on-demand scanning of files/downloads for known malware signatures
- [ ] `auditd` — deliberately **not** containerized if pursued. It hooks into the Linux kernel's audit subsystem via netlink, a single system-wide resource, not something namespaced per-container the way network interfaces are — containerizing it fights the tool rather than using it well. If ever pursued: install directly on the host, outside this project's container-everything pattern. Deferred indefinitely, not a rejection — revisit anytime.

---

## Epoch 5 — Host Defense (fail2ban)
Goal: extend defense-in-depth to the host itself — react to suspicious local activity (repeated failed logins, etc.), complementing Suricata's network-level detection with host-level response.

**Status: deferred, not built.** Checked the first item below — this host has no real target (`sshd` inactive/disabled, no other auth-facing service running). Consistent with "add tools only when you have a concrete need." Revisit if that ever changes (e.g. SSH gets deliberately enabled).

### Epic: Host Intrusion Prevention (fail2ban)
- [x] **Confirm there's an actual target before building around one**: identify which auth-facing services (SSH, etc.) are actually running/exposed on this host. `fail2ban` watches logs from services facing login attempts — no exposed service means nothing meaningful for it to protect.
  - Checked: `sshd` inactive + disabled. No FTP/VNC/Samba/Cockpit/web-admin running either. Only listeners are localhost-only (VS Code), DNS resolution, LLMNR, and KDE Connect (pairing-based auth, not a fail2ban fit). **No target — epic deferred**, remaining items below not started.
- [ ] Decide: separate image in `defense/fail2ban/`, same per-tool-family subdirectory pattern as `scan-tools/` and `defense/suricata/`
- [ ] **Test empirically, don't assume**: can a containerized `fail2ban` actually write firewall rules that take effect against the host (`--network host` + capabilities)? This is the load-bearing assumption for the whole epic — validate it early, the same way the Suricata capability requirement was confirmed by testing before/after `--cap-add`, not assumed from docs.
- [ ] Configure `fail2ban` to watch the confirmed real log source(s) from the item above
- [ ] Decide how to view what's been banned (parallel to Suricata's `logs` subcommand)
- [ ] Wrapper script (start/stop/status, extending the same `case`-statement pattern from `suricata-ctl.sh`)

---

## Epoch 6 — Certificate & TLS Auditing (testssl.sh)
Goal: close the loop on the very first real finding this project ever produced — `quick-recon.sh`'s first-ever test run caught an expired, generic SSL cert on this network's own router admin panel. This epic turns that one-off catch into a systematic, repeatable audit tool for exactly that class of problem (expired/weak certs, deprecated protocols, weak ciphers, known TLS vulnerabilities).

### Epic: TLS/SSL Configuration Auditing
- [x] **Decide: fold into the existing `scan-tools/` image, or a new subdirectory?** Decision: folded in. Unlike Suricata/`fail2ban`, this tool has no different container lifecycle — it's a one-shot, single-target audit, architecturally identical in shape to `quick-recon.sh`. `testssl.sh` installed as an apt package alongside the other tools in `scan-tools/Dockerfile`; script lives in `scan-tools/scripts/` next to the rest.
- [x] **Confirm capability requirements empirically, don't assume**: confirmed — `testssl` ran clean against a real target with no `--cap-add` flags at all. As predicted, it's a standard TLS client (like a browser's HTTPS connection), not raw-socket/packet-capture tooling, so it needs none of the `NET_RAW`/`NET_ADMIN` capabilities the rest of `scan-tools` requires.
- [x] Decide accepted target format(s) — single required positional argument (plain hostname or IP), same pattern as `quick-recon.sh`
- [x] Check whether `testssl.sh` has a native "write results to file" flag — yes: `--logfile|-oL` (plain text), plus JSON/CSV/HTML variants. Used `-oL` directly, matching the `nmap -oN` convention, since every other saved scan result in this project is plain text.
- [x] Same conventions as every other `scan-tools` script: `--help`, required target (no sensible default for a single host, same reasoning as `quick-recon.sh`), timestamped output into `~/kali-data`
- [x] Add the new script to `ci.yml`'s `shellcheck` glob — already covered: the existing glob (`scan-tools/scripts/*.sh`) matches the whole directory, no change needed. Confirmed rather than assumed, given the exact gap that had to be caught and fixed for Suricata.
- [x] Test against the real, already-known target: this network's router admin panel (`192.168.1.254`) — re-caught and fully detailed the same cert that started this whole thread. `testssl` confirmed: self-signed, expired 2025-05-29, no SAN, hostname mismatch, `Chain of trust NOT ok`, capped to Grade T. Underlying protocol/cipher config is actually solid (TLS 1.2/1.3 only, strong AEAD ciphers, forward secrecy) — the failure is entirely the certificate, not the crypto.

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
| Epoch 5 — Host Defense | `fail2ban` confirmed to actually ban IPs from a container against a real, confirmed log source; wrapper script parallel to `suricata-ctl.sh` |
| Epoch 6 — Certificate & TLS Auditing | `testssl.sh` script tested against the router's real admin panel, correctly re-catching the expired-cert finding from this project's first-ever scan |
