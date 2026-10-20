#!/usr/bin/env bash
# WHAT:    End-to-end proof of the reading-stats feature: launch the packaged
#          sioyek on a PDF, turn pages via the app's own IPC (--execute-command
#          next_page) with real dwell time, invoke reading_stats, quit (which
#          triggers the persist flush), then verify the sqlite3 evidence in the
#          global DB and the exported CSV.
# WHY:     The brief's final gate requires observed artifacts — page_time rows,
#          a page_visits progression timeline, and a CSV on disk — not a claim.
#          An inline shell sequence would evaporate; this program reproduces the
#          whole scenario deterministically.
# INPUTS:  $1 binary   (default: build/sioyek)
#          $2 pdf      (default: tutorial.pdf)
#          $3 db       (default: ~/.local/share/sioyek/shared.db)
#          $4 dwell_s  seconds per page (default: 3)
#          $5 turns    number of next_page IPC calls (default: 3)
# OUTPUTS: writes run log + copies of evidence under scripts/logs/<ts>/;
#          mutates the user's global sioyek DB ONLY through the app's own
#          tracked writes (page_visits/page_time rows for the test PDF);
#          launches and quits a GUI sioyek instance.
#          exit 0 = all proofs pass, 1 = a proof failed, 64 = usage error.
# USAGE (combinatorial):
#   ./scripts/AUTO-verify-reading-stats-e2e.sh
#       # standard gate: build/sioyek, tutorial.pdf, 3 turns x 3s dwell
#   ./scripts/AUTO-verify-reading-stats-e2e.sh build/sioyek tutorial.pdf ~/.local/share/sioyek/shared.db 5 4
#       # longer dwell / more turns for a heavier timeline
#   ./scripts/AUTO-verify-reading-stats-e2e.sh build/sioyek /path/to/other.pdf
#       # proof against a different document
#   ./scripts/AUTO-verify-reading-stats-e2e.sh --help
#       # INVALID combination style: unknown arg -> exits 64
# RE-RUN SAFETY: idempotent w.r.t. the repo; each run APPENDS new page_visits
#          rows (by design — that is the timeline) and rewrites the CSV.
#          Never hand-mutates the DB: SELECT-only sqlite3 access.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$REPO_ROOT"

BIN="${1:-build/sioyek}"
PDF="${2:-tutorial.pdf}"
DB="${3:-$HOME/.local/share/sioyek/shared.db}"
DWELL="${4:-3}"
TURNS="${5:-3}"

case "$BIN" in -h|--help) echo "see header"; exit 64 ;; esac
[ -x "$BIN" ] || { echo "usage error: binary '$BIN' not executable" >&2; exit 64; }
[ -f "$PDF" ] || { echo "usage error: pdf '$PDF' missing" >&2; exit 64; }

LOGDIR="$(dirname "$(readlink -f "$0")")/logs/$(date +%Y%m%dT%H%M%S)"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/e2e.log"
exec > >(tee "$LOG") 2>&1

echo "== e2e: bin=$BIN pdf=$PDF db=$DB dwell=${DWELL}s turns=$TURNS =="

# refuse to run against a sioyek instance the user already has open? No —
# IPC commands route to the existing instance; that is still the app's own
# command surface, but the DB would be shared either way. We proceed and rely
# on checksum-scoped queries.
setsid "$BIN" "$REPO_ROOT/$PDF" >"$LOGDIR/sioyek.stdout.log" 2>&1 &
sleep 5

# focus the sioyek window so isActiveWindow()-gated tracking accumulates
WIN_ID="$(xdotool search --name 'sioyek' | tail -1 || true)"
if [ -n "$WIN_ID" ]; then
    xdotool windowactivate "$WIN_ID"
else
    echo "WARNING: no sioyek window found via xdotool; tracking may not accumulate"
fi

"$BIN" --execute-command goto_beginning >/dev/null 2>&1 || true
sleep "$DWELL"

for i in $(seq 1 "$TURNS"); do
    "$BIN" --execute-command next_page
    [ -n "$WIN_ID" ] && xdotool windowactivate "$WIN_ID"
    sleep "$DWELL"
done

"$BIN" --execute-command reading_stats
sleep 2
"$BIN" --execute-command quit
sleep 3

CHECKSUM="$(sqlite3 "$DB" "select document_checksum from document_hash order by rowid desc limit 1;" || true)"
echo "checksum under test (latest in document_hash): $CHECKSUM"
if [ -z "$CHECKSUM" ]; then
    echo "FAIL: no document_hash row found"; exit 1
fi

echo "== page_time rows =="
sqlite3 -header -column "$DB" \
    "select page_number, round(total_seconds,2) as total_seconds, visit_count, last_visit
     from page_time where document_checksum='$CHECKSUM' order by page_number;" | tee "$LOGDIR/page_time.txt"

echo "== page_visits timeline (latest run) =="
sqlite3 -header -column "$DB" \
    "select id, page_number, enter_time, round(duration_seconds,2) as duration_seconds
     from page_visits where document_checksum='$CHECKSUM' order by id desc limit $((TURNS+2));" | tee "$LOGDIR/page_visits.txt"

FAIL=0
PT_ROWS="$(sqlite3 "$DB" "select count(*) from page_time where document_checksum='$CHECKSUM';")"
[ "$PT_ROWS" -ge 1 ] || { echo "FAIL: no page_time rows"; FAIL=1; }

# ascending enter_time within the latest (TURNS+1) visits
ORDER_OK="$(sqlite3 "$DB" "
    select count(*) from (
        select enter_time, lag(enter_time) over (order by id) as prev
        from (select id, enter_time from page_visits where document_checksum='$CHECKSUM'
              order by id desc limit $((TURNS+1)))
    ) where prev is not null and enter_time < prev;")"
[ "$ORDER_OK" = "0" ] || { echo "FAIL: enter_time not ascending"; FAIL=1; }

# plausible durations: 0 < duration <= 300 cap
BAD_DUR="$(sqlite3 "$DB" "
    select count(*) from (select duration_seconds from page_visits
        where document_checksum='$CHECKSUM' order by id desc limit $((TURNS+1)))
    where duration_seconds <= 0 or duration_seconds > 300;")"
[ "$BAD_DUR" = "0" ] || { echo "FAIL: implausible durations"; FAIL=1; }

CSV="$(ls -t "$HOME/.local/share/sioyek"/reading_stats_*.csv 2>/dev/null | head -1 || true)"
if [ -n "$CSV" ] && [ -f "$CSV" ]; then
    echo "== CSV: $CSV =="
    head -20 "$CSV"
    cp "$CSV" "$LOGDIR/"
else
    echo "FAIL: no reading_stats_*.csv written"; FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "E2E PROOF GREEN"
else
    echo "E2E PROOF RED"; exit 1
fi
