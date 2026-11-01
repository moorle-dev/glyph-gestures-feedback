#!/usr/bin/env bash
# Reads an issue-form body from $BODY and prints one line per field that does not hold a real
# version: "package" and/or "unity". Prints nothing when both are fine. Never echoes the body.
set -u
field() {
  # text under the "### <label>" heading, first non-empty line
  printf '%s\n' "$BODY" | tr -d '\r' | awk -v h="### $1" '
    $0 == h { on = 1; next }
    /^### / { on = 0 }
    on && NF { print; exit }'
}
pkg="$(field 'Glyph Gestures version')"
unity="$(field 'Unity version')"
pkg_re='^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$'
unity_re='^[0-9]+\.[0-9]+\.[0-9]+[abfp][0-9]+$'
[[ "$pkg" =~ $pkg_re ]] || echo package
[[ "$unity" =~ $unity_re ]] || echo unity
# an invoice number in a public issue can be copied by anyone
printf '%s' "$BODY" | tr '\n\r' '  ' | grep -Eqi 'invoice[^0-9]{0,20}[0-9]{5,}' && echo invoice
exit 0
