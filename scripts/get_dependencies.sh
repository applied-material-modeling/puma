#!/usr/bin/env bash
#
# get_dependencies.sh — initialize PUMA's pinned MOOSE and NEML2 submodules and,
# optionally, build NEML2 into MOOSE.
#
# PUMA pins the exact versions it builds against as git submodules:
#
#   MOOSE  : https://github.com/hugary1995/moose.git   @ neml2-v3-migration   -> moose/
#   NEML2  : https://github.com/hdt5kt/neml2.git        @ pyzag_v3_port         -> neml2/
#
# A fresh `git clone --recurse-submodules` already populates both. This helper is for
# checkouts cloned without --recurse-submodules, and to run the NEML2 build step that
# links the neml2/ submodule into MOOSE (via NEML2_SRC_DIR, overriding MOOSE's own
# pinned NEML2 submodule).
#
# Usage:
#   scripts/get_dependencies.sh [--build] [--help]
#
# Options:
#   --build   After initializing submodules, configure MOOSE and build NEML2 against
#             the neml2/ submodule. Requires an active conda env with torch + libtorch,
#             and MOOSE's PETSc/libMesh already built (see README 'Installation Instructions').
#   --help    Show this message and exit.
#
# Environment:
#   MOOSE_DIR   Build against a MOOSE checkout outside the repo instead of the moose/
#               submodule. When set, the moose/ submodule is left uninitialized.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUMA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DO_BUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)   DO_BUILD=true; shift ;;
    --help|-h) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "error: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

cd "${PUMA_DIR}"

# NEML2 submodule is always needed (MOOSE links against it).
info "Initializing neml2/ submodule"
git submodule update --init neml2

# MOOSE submodule only when not pointing at an external MOOSE_DIR.
MOOSE_PATH="${MOOSE_DIR:-${PUMA_DIR}/moose}"
if [[ -n "${MOOSE_DIR:-}" ]]; then
  info "MOOSE_DIR set (${MOOSE_DIR}); leaving moose/ submodule uninitialized"
else
  info "Initializing moose/ submodule"
  git submodule update --init moose
fi

info "Submodules:"
git submodule status neml2 ${MOOSE_DIR:+} $( [[ -z "${MOOSE_DIR:-}" ]] && echo moose )

if [[ "${DO_BUILD}" == true ]]; then
  echo
  info "Configuring MOOSE (${MOOSE_PATH}) and building NEML2 from ${PUMA_DIR}/neml2"
  info "PETSc/libMesh must already be built — see README 'Installation Instructions'."
  ( cd "${MOOSE_PATH}" \
      && ./configure --with-libtorch --with-neml2 \
      && NEML2_SRC_DIR="${PUMA_DIR}/neml2" ./scripts/update_and_rebuild_neml2.sh --skip-submodule-update )
  echo
  info "NEML2 built. Now build PUMA:"
  echo "  cd ${PUMA_DIR} && MOOSE_DIR=${MOOSE_PATH} make -j\${MOOSE_JOBS:-4}"
else
  cat <<EOF

Submodules ready. Next steps (see README 'Installation Instructions' for PETSc/libMesh/libtorch):

  # Build the pinned NEML2 into MOOSE:
  cd ${MOOSE_PATH}
  ./configure --with-libtorch --with-neml2
  NEML2_SRC_DIR=${PUMA_DIR}/neml2 ./scripts/update_and_rebuild_neml2.sh --skip-submodule-update

  # Build PUMA:
  cd ${PUMA_DIR}
  make -j\${MOOSE_JOBS:-4}

Tip: re-run with --build to run the configure + NEML2 build automatically.
EOF
fi
