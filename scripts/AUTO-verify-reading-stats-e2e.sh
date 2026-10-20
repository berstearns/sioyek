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
#          $3 db       global db (default: ~/.local/share/sioyek/shared.db)
#          $4 dwell_s  seconds per page (default: 3)
#          $5 turns    number of next_page IPC calls (default: 3)
#          env LOCALDB local db holding document_hash path->checksum mapping
#                      (default: ~/.local/share/sioyek/local.db)
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
LOCALDB="${LOCALDB:-$HOME/.local/share/sioyek/local.db}"
DWELL="${4:-3}"
TURNS="${5:-3}"

case "$BIN" in -h|--help) echo "see header"; exit 64 ;; esac
[ -x "$BIN" ] || { echo "usage error: binary '$BIN' not executable" >&2; exit 64; }
[ -f "$PDF" ] || { echo "usage error: pdf '$PDF' missing" >&2; exit 64; }

LOGDIR="$(dirname "$(readlink -f "$0")")/logs/$(date +%Y%m%dT%H%M%S)"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/e2e.log"
exec > >(tee "$LOG") 2>&1

echo "== e2e: bin=$BIN pdf=$PDF db=$DB localdb=$LOCALDB dwell=${DWELL}s turns=$TURNS =="

# NOTE: the path->checksum mapping (document_hash) lives in local.db, NOT in
# the global db — verified against sqlite_master: create_document_hash_table()
# executes on local_db (pdf_viewer/database.cpp). page_visits/page_time are in
# the global db.

setsid "$BIN" "$REPO_ROOT/$PDF" >"$LOGDIR/sioyek.stdout.log" 2>&1 &
SIO_PID=$!
sleep 5

# focus OUR sioyek window so isActiveWindow()-gated tracking accumulates.
# search by pid: `xdotool search --name sioyek` can match unrelated windows
# (e.g. a browser tab with 'sioyek' in the title) and steal focus from the PDF
# viewer instead of granting it — that exact failure produced a red run where
# only the first dwell was recorded.
WIN_ID=""
for attempt in 1 2 3 4 5; do
    WIN_ID="$(xdotool search --pid "$SIO_PID" 2>/dev/null | tail -1 || true)"
    [ -n "$WIN_ID" ] && break
    sleep 1
done
if [ -z "$WIN_ID" ]; then
    echo "FAIL: no X window owned by sioyek pid $SIO_PID"; exit 1
fi

focus_window() {
    xdotool windowactivate "$WIN_ID"
    sleep 1
    ACTIVE="$(xdotool getactivewindow 2>/dev/null || true)"
    if [ "$ACTIVE" != "$WIN_ID" ]; then
        echo "WARNING: active window is $ACTIVE, expected $WIN_ID — retrying"
        xdotool windowactivate "$WIN_ID"
        sleep 1
        ACTIVE="$(xdotool getactivewindow 2>/dev/null || true)"
    fi
    echo "active window: $ACTIVE (want $WIN_ID)"
    [ "$ACTIVE" = "$WIN_ID" ]
}

focus_window || { echo "FAIL: could not focus the sioyek window"; exit 1; }

"$BIN" --execute-command goto_beginning >/dev/null 2>&1 || true
sleep "$DWELL"

for i in $(seq 1 "$TURNS"); do
    "$BIN" --execute-command next_page
    focus_window || { echo "FAIL: lost focus at turn $i"; exit 1; }
    sleep "$DWELL"
done

"$BIN" --execute-command reading_stats
sleep 2
"$BIN" --execute-command quit
sleep 3

PDF_ABS="$REPO_ROOT/$PDF"
CHECKSUM="$(sqlite3 "file:$LOCALDB?mode=ro" \
    "select hash from document_hash where path='$PDF_ABS' order by id desc limit 1;" || true)"
echo "checksum under test (document_hash for $PDF_ABS): $CHECKSUM"
if [ -z "$CHECKSUM" ]; then
    echo "FAIL: no document_hash row for $PDF_ABS in $LOCALDB"; exit 1
fi

echo "== page_time rows =="
sqlite3 -header -column "file:$DB?mode=ro" \
    "select page_number, round(total_seconds,2) as total_seconds, visit_count, last_visit
     from page_time where document_checksum='$CHECKSUM' order by page_number;" | tee "$LOGDIR/page_time.txt"

echo "== page_visits timeline (latest run) =="
sqlite3 -header -column "file:$DB?mode=ro" \
    "select id, page_number, enter_time, round(duration_seconds,2) as duration_seconds
     from page_visits where document_checksum='$CHECKSUM' order by id desc limit $((TURNS+2));" | tee "$LOGDIR/page_visits.txt"

FAIL=0
PT_ROWS="$(sqlite3 "file:$DB?mode=ro" "select count(*) from page_time where document_checksum='$CHECKSUM';")"
[ "$PT_ROWS" -ge 1 ] || { echo "FAIL: no page_time rows"; FAIL=1; }

# expect a per-page aggregate for every visited page (TURNS next_page calls
# from page 0 => TURNS+1 distinct pages)
[ "$PT_ROWS" -ge $((TURNS+1)) ] || { echo "FAIL: only $PT_ROWS distinct pages tracked, expected $((TURNS+1))"; FAIL=1; }

# ascending enter_time within the latest (TURNS+1) visits
ORDER_OK="$(sqlite3 "file:$DB?mode=ro" "
    select count(*) from (
        select enter_time, lag(enter_time) over (order by id) as prev
        from (select id, enter_time from page_visits where document_checksum='$CHECKSUM'
              order by id desc limit $((TURNS+1)))
    ) where prev is not null and enter_time < prev;")"
[ "$ORDER_OK" = "0" ] || { echo "FAIL: enter_time not ascending"; FAIL=1; }

# plausible durations: 0 < duration <= 300 cap
BAD_DUR="$(sqlite3 "file:$DB?mode=ro" "
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
