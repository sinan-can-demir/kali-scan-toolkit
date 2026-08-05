# Bash Notation Cheat Sheet

Quick reference for the syntax patterns used in `scripts/`. None of these are meant to be derived from first principles — they're fixed vocabulary, memorized with use.

## Conditionals

```bash
if [[ condition ]]; then
    commands
fi
```
- `if` / `then` / `fi` — like any language's if-block, but bash requires the literal word `fi` ("if" spelled backwards) to close it. No curly braces.
- `[[ ... ]]` — the "test something" brackets. Everything inside is the condition being evaluated.

## Test operators (go inside `[[ ]]`)

| Operator | Meaning |
|---|---|
| `-z "$VAR"` | true if `$VAR` is empty (zero-length) |
| `-n "$VAR"` | true if `$VAR` is *not* empty |
| `-f path` | true if `path` is a regular file that exists |
| `-d path` | true if `path` is a directory that exists |
| `"$A" == "$B"` | true if the strings are exactly equal |
| `cond1 || cond2` | true if *either* condition is true (OR) |
| `cond1 && cond2` | true if *both* conditions are true (AND) |

Example from `scan-subnet.sh`:
```bash
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
```
"If the first argument equals `-h`, OR it equals `--help`..."

## Positional parameters (script arguments)

| Symbol | Meaning |
|---|---|
| `$1`, `$2`, ... | the 1st, 2nd, ... word typed after the script name on the command line |
| `"$1"` | always quote it — unquoted variables get word-split on spaces, which causes bugs the moment a value ever contains one |

## Parameter expansion (transforming a variable's value)

| Pattern | Meaning |
|---|---|
| `${VAR:-default}` | use `$VAR` if it's set and non-empty, otherwise use `default` |
| `${VAR//pattern/replacement}` | replace *every* occurrence of `pattern` inside `$VAR` with `replacement` |

Example from `scan-subnet.sh`:
```bash
TARGET="${1:-192.168.1.0/24}"       # $1, or fall back to this subnet
SAFE_TARGET="${TARGET//\//_}"       # replace every "/" with "_"
```
The `\/` inside the replacement pattern is a `/` character escaped with `\` — needed because `/` is also the separator in this syntax, so a literal slash has to be marked as "not a separator."

## Command substitution

```bash
TS=$(date +%Y%m%d_%H%M%S)
```
`$( ... )` runs the command inside and replaces the whole expression with whatever it printed to stdout. Same idea as backticks in older scripts, but nestable and easier to read.

## Exit codes

Every command/script returns a number when it finishes: `0` means success, anything else means some kind of failure. This is how a parent process (or the shell itself, or CI) knows whether what it called worked.

| Situation | Exit code |
|---|---|
| Script did what it was supposed to do (including successfully printing `--help`) | `exit 0` |
| Script couldn't proceed (missing required argument, bad input, etc.) | `exit 1` (or another non-zero number if you want to distinguish error types) |

This is why `--help` and "missing required argument" need to be *separate* `if` blocks even though both print a usage message — they represent different outcomes and need different exit codes.

## Docker flags used in these scripts

| Flag | Meaning |
|---|---|
| `--rm` | delete the container as soon as it exits — no leftover stopped containers piling up |
| `--network host` | share the host's network stack directly, instead of Docker's isolated bridge network — needed so scans see real devices on the LAN |
| `--cap-add=NET_RAW --cap-add=NET_ADMIN` | grant the specific Linux capabilities `nmap` needs for raw-socket scanning, without giving the container full root-equivalent privilege via `--privileged` |
| `-v ~/kali-data:/root/data:z` | mount the host directory into the container at that path; the `:z` label is required on SELinux systems (Fedora) or writes fail with `Permission denied` — harmless no-op on non-SELinux systems |
