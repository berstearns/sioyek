#!/usr/bin/env bash
# WHAT:    Build sioyek (qmake/make), package the binary + runtime configs into
#          build/, and smoke-check `./build/sioyek --version`.
# WHY:     The reading-stats feature brief requires every commit on the feature
#          branch to be proven green by a tracked, re-runnable build program; an
#          inline `make -j12` would leave no record of flags, paths, or the
#          packaging steps that turn the tree into a runnable app.
# INPUTS:  -j N / --jobs N   parallel make jobs (default: 12)
#          --configure       force re-run of qmake6 even if Makefile exists
#          --skip-package    build only; do not refresh build/ payload
#          --skip-smoke      skip the --version smoke check
#          env QMAKE         qmake binary (default: qmake6)
# OUTPUTS: refreshes ./sioyek (make output) and ./build/{sioyek,prefs.config,
#          prefs_user.config,keys.config,keys_user.config,shaders/,tutorial.pdf};
#          appends nothing outside the repo; exit 0 = build+package(+smoke) ok,
#          exit 1 = build/package failure, 2 = smoke failure, 64 = usage error.
# USAGE (combinatorial):
#   ./scripts/AUTO-build-sioyek.sh
#       # default: incremental make -j12, package, smoke — the standard gate
#   ./scripts/AUTO-build-sioyek.sh -j 4
#       # weaker machine: fewer jobs, still full package+smoke
#   ./scripts/AUTO-build-sioyek.sh --configure
#       # .pro changed or Makefile missing: qmake6 first, then build
#   ./scripts/AUTO-build-sioyek.sh --skip-package
#       # quick compile check while iterating on code
#   ./scripts/AUTO-build-sioyek.sh --skip-smoke
#       # package but don't launch the binary (e.g. headless box)
#   ./scripts/AUTO-build-sioyek.sh --configure --skip-package --skip-smoke
#       # minimal re-configure + compile sanity pass
#   ./scripts/AUTO-build-sioyek.sh --bogus
#       # INVALID: unknown flag; exits 64 with usage message
# RE-RUN SAFETY: idempotent — make is incremental, packaging overwrites the same
#          build/ payload, smoke is read-only. Safe to run after every commit.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$REPO_ROOT"

JOBS=12
DO_CONFIGURE=0
DO_PACKAGE=1
DO_SMOKE=1
QMAKE_BIN="${QMAKE:-qmake6}"

while [ $# -gt 0 ]; do
    case "$1" in
        -j|--jobs)
            [ $# -ge 2 ] || { echo "usage error: $1 needs a number" >&2; exit 64; }
            JOBS="$2"; shift 2 ;;
        --configure)   DO_CONFIGURE=1; shift ;;
        --skip-package) DO_PACKAGE=0; shift ;;
        --skip-smoke)    DO_SMOKE=0; shift ;;
        *) echo "usage error: unknown flag '$1'" >&2; exit 64 ;;
    esac
done

if [ "$DO_CONFIGURE" -eq 1 ] || [ ! -f Makefile ]; then
    echo "== configure: $QMAKE_BIN CONFIG+=linux_app_image =="
    "$QMAKE_BIN" 'CONFIG+=linux_app_image' pdf_viewer_build_config.pro
fi

echo "== build: make -j$JOBS =="
make -j"$JOBS"

if [ "$DO_PACKAGE" -eq 1 ]; then
    echo "== package into build/ =="
    mkdir -p build
    mv -f sioyek build/sioyek
    cp -f pdf_viewer/prefs.config pdf_viewer/prefs_user.config \
          pdf_viewer/keys.config pdf_viewer/keys_user.config build/
    rm -rf build/shaders
    cp -r pdf_viewer/shaders build/shaders
    cp -f tutorial.pdf build/tutorial.pdf
fi

if [ "$DO_SMOKE" -eq 1 ]; then
    echo "== smoke: ./build/sioyek --version =="
    VERSION_OUT="$(./build/sioyek --version)"
    echo "$VERSION_OUT"
    echo "$VERSION_OUT" | grep -q "sioyek 2.0.0" || { echo "SMOKE FAILED: expected 'sioyek 2.0.0'" >&2; exit 2; }
    echo "SMOKE OK"
fi

echo "BUILD GREEN"
