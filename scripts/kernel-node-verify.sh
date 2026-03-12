#!/usr/bin/env bash
# /home/builder/scripts/kernel-node-verify.sh
# Unified kernel validation framework
# Copyright (C) 2026  Lewis
# Licensed under GPLv3
#
# This validator performs:
#   --pre   : Tarball validation
#   --stage : Directory validation
#   --post  : Live system validation
#
# All modes use unified logging, vroot abstraction, and deterministic checks.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; 
source "$SCRIPT_DIR/modules/core/logging.sh"; 
source "$SCRIPT_DIR/modules/core/normalize.sh"; 
source "$SCRIPT_DIR/modules/core/args.sh"; 
source "$SCRIPT_DIR/modules/io/vroot.sh"; 
source "$SCRIPT_DIR/modules/io/tarops.sh"; 
source "$SCRIPT_DIR/modules/checks/pre.sh"; 
source "$SCRIPT_DIR/modules/checks/stage.sh"; 
source "$SCRIPT_DIR/modules/checks/post.sh";

# Global counters for PASS/WARN/FAIL
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Mode variables
MODE=""
TARBALL=""
STAGEDIR=""



# Core utilities

usage() {
  cat >&2 <<EOF
Usage:
  $0 --pre <tarball>
  $0 --stage <directory>
  $0 --post

Modes:
  --pre    Validate a kernel tarball (no filesystem changes)
  --stage  Validate an extracted staging directory
  --post   Validate the live system (versioned artifacts)

Exactly one mode is required.
EOF
}

MODE=""
TARGET=""
STAGE_DIR=""

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pre)
      if [[ -n "$MODE" ]]; then
        echo "ERROR: Multiple modes specified." >&2
        usage
        exit 1
      fi
      MODE="pre"
      TARGET="${2:-}"
      shift 2
      ;;
    --stage)
      if [[ -n "$MODE" ]]; then
        echo "ERROR: Multiple modes specified." >&2
        usage
        exit 1
      fi
      MODE="stage"
      STAGE_DIR="${2:-}"
      shift 2
      ;;
    --post)
      if [[ -n "$MODE" ]]; then
        echo "ERROR: Multiple modes specified." >&2
        usage
        exit 1
      fi
      MODE="post"
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "ERROR: No mode specified." >&2
  usage
  exit 1
fi

case "$MODE" in
  pre)
    if [[ -z "$TARGET" ]]; then
      echo "ERROR: --pre requires a tarball path." >&2
      usage
      exit 1
    fi
    if [[ ! -f "$TARGET" ]]; then
      echo "ERROR: Tarball does not exist: $TARGET" >&2
      exit 1
    fi
    log_section "[PRE] Tarball validation: $TARGET"
    vroot_init tar "$TARGET"
    run_pre_checks "$TARGET"
    final_summary
    exit $?
    ;;

  stage)
    if [[ -z "$STAGE_DIR" ]]; then
      echo "ERROR: --stage requires a directory path." >&2
      usage
      exit 1
    fi
    if [[ ! -d "$STAGE_DIR" ]]; then
      echo "ERROR: Stage directory does not exist: $STAGE_DIR" >&2
      exit 1
    fi
    log_section "[STAGE] Directory validation: $STAGE_DIR"
    vroot_init dir "$STAGE_DIR"
    run_stage_checks "$STAGE_DIR"
    final_summary
    exit $?
    ;;

  post)
    log_section "[POST] Live system validation"
    vroot_init live "/"
    run_post_checks
    final_summary
    exit $?
    ;;

  *)
    echo "ERROR: Unknown mode: $MODE" >&2
    usage
    exit 1
    ;;
esac

# If we reached here without exiting inside a mode block,
# something unexpected happened. This is a defensive guard.
log_section "[INTERNAL] Unexpected fall-through"
log_fail "Validator reached end-of-file without a mode exit. This should never occur."
final_summary
exit 99
