#!/usr/bin/env bash
# Decides what intake changes on a bug-form issue and prints one action per line.
# Inputs, all environment variables:
#   ACTION      opened or edited
#   LABELS      the issue's labels, one per line
#   MISSING     the lines of intake-check.sh without "invoice" (empty when both versions are real)
#   LAST_ACTOR  who made the latest needs-info label event (empty when there is none)
# Actions: "remove <label>", "add <label>", "comment". Prints nothing when nothing changes.
# A needs-info the owner set by hand has the owner as actor, so an edit never removes it.
set -u
has() { grep -qx "$1" <<<"${LABELS:-}"; }
if [ -z "${MISSING:-}" ]; then
  if [ "${ACTION:-}" = edited ] && has needs-info && [ "${LAST_ACTOR:-}" = "github-actions[bot]" ]; then
    echo "remove needs-info"
    echo "add needs-triage"
  fi
  exit 0
fi
[ "${ACTION:-}" = opened ] || exit 0
has needs-triage && echo "remove needs-triage"
echo "add needs-info"
echo "comment"
exit 0
