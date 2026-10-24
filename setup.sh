#!/usr/bin/env bash
# Copy .env.example to .env and fill the secrets this app generates itself.
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  cp .env.example .env
fi

set_if_blank() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"

  awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    index($0, key "=") == 1 {
      current = substr($0, length(key) + 2)
      if (current == "") {
        print key "=" value
      } else {
        print $0
      }
      found = 1
      next
    }
    { print }
    END {
      if (!found) print key "=" value
    }
  ' .env >"$tmp"

  mv "$tmp" .env
}

set_if_blank SECRET_KEY_BASE "$(openssl rand -base64 64 | tr -d '\n')"
set_if_blank VAULT_KEY "$(openssl rand -base64 32 | tr -d '\n')"
set_if_blank MCP_TOKEN "$(openssl rand -hex 32)"

echo "setup.sh: .env is ready. SECRET_KEY_BASE, VAULT_KEY, and MCP_TOKEN are set."
echo "Put your Stripe test key and OpenRouter key in .env before you need them."
