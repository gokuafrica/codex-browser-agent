#!/usr/bin/env bash
set -euo pipefail

BROWSER="${1:-auto}"
PLUGIN_NAME="codex-browser-agent"
HOME_DIR="${HOME}"
PROFILE_DIR="${HOME_DIR}/.playwright-mcp-profile"
PLUGIN_DIR="${HOME_DIR}/plugins/${PLUGIN_NAME}"
MARKETPLACE_PATH="${HOME_DIR}/.agents/plugins/marketplace.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SOURCE_DIR="${SCRIPT_DIR}/plugin"

detect_browser_from_profile() {
  local last_browser
  last_browser="${PROFILE_DIR}/Last Browser"
  if [[ ! -f "${last_browser}" ]]; then
    return 1
  fi

  if iconv -f UTF-16LE -t UTF-8 "${last_browser}" 2>/dev/null | grep -qi "msedge\.exe"; then
    printf '%s\n' "msedge"
    return 0
  fi
  if iconv -f UTF-16LE -t UTF-8 "${last_browser}" 2>/dev/null | grep -qi "chrome\.exe"; then
    printf '%s\n' "chrome"
    return 0
  fi
  if iconv -f UTF-16LE -t UTF-8 "${last_browser}" 2>/dev/null | grep -qi "firefox"; then
    printf '%s\n' "firefox"
    return 0
  fi

  return 1
}

is_browser_available() {
  case "$1" in
    chrome)
      command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1 || [[ -e "/Applications/Google Chrome.app" ]]
      ;;
    msedge)
      command -v microsoft-edge >/dev/null 2>&1 || command -v msedge >/dev/null 2>&1 || [[ -e "/Applications/Microsoft Edge.app" ]]
      ;;
    firefox)
      command -v firefox >/dev/null 2>&1 || [[ -e "/Applications/Firefox.app" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

choose_browser() {
  if [[ "${BROWSER}" != "auto" ]]; then
    if is_browser_available "${BROWSER}"; then
      printf '%s\n' "${BROWSER}"
      return 0
    fi
    printf 'Requested browser %s is not installed.\n' "${BROWSER}" >&2
    exit 1
  fi

  if profile_browser="$(detect_browser_from_profile)"; then
    if is_browser_available "${profile_browser}"; then
      printf '%s\n' "${profile_browser}"
      return 0
    fi
  fi

  for candidate in chrome msedge firefox; do
    if is_browser_available "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  printf 'No supported browser found. Install Chrome, Edge, or Firefox.\n' >&2
  exit 1
}

printf '\n=== Codex Browser Agent Installer ===\n'
printf '\n[1/4] Checking prerequisites...\n'
command -v node >/dev/null 2>&1 || { printf 'Node.js was not found on PATH.\n' >&2; exit 1; }
command -v npx >/dev/null 2>&1 || { printf 'npx was not found on PATH.\n' >&2; exit 1; }
NODE_MAJOR="$(node -p 'parseInt(process.version.slice(1), 10)')"
if [[ "${NODE_MAJOR}" -lt 18 ]]; then
  printf 'Node.js v18+ is required. Found major version %s.\n' "${NODE_MAJOR}" >&2
  exit 1
fi
printf '  Node.js OK\n'

printf '\n[2/4] Selecting browser...\n'
SELECTED_BROWSER="$(choose_browser)"
printf '  Using: %s\n' "${SELECTED_BROWSER}"

printf '\n[3/4] Installing plugin bundle...\n'
mkdir -p "${PROFILE_DIR}" "$(dirname "${PLUGIN_DIR}")"
rm -rf "${PLUGIN_DIR}"
cp -R "${PLUGIN_SOURCE_DIR}" "${PLUGIN_DIR}"

python3 - <<'PY' "${PLUGIN_DIR}" "${PROFILE_DIR}" "${SELECTED_BROWSER}"
import json
import pathlib
import sys

plugin_dir = pathlib.Path(sys.argv[1])
profile_dir = sys.argv[2]
browser = sys.argv[3]

mcp = {
    "mcpServers": {
        "playwright": {
            "type": "local",
            "command": [
                "npx",
                "-y",
                "@playwright/mcp@latest",
                "--browser",
                browser,
                "--user-data-dir",
                profile_dir,
            ],
            "note": "Installed by codex-browser-agent. Uses a persistent Playwright profile so future Codex sessions can reuse browser login state.",
        }
    }
}

(plugin_dir / ".mcp.json").write_text(json.dumps(mcp, indent=2) + "\n", encoding="utf-8")
PY

printf '  Plugin installed to: %s\n' "${PLUGIN_DIR}"

printf '\n[4/4] Updating Codex marketplace...\n'
python3 - <<'PY' "${MARKETPLACE_PATH}" "${PLUGIN_NAME}"
import json
import pathlib
import sys

marketplace_path = pathlib.Path(sys.argv[1])
plugin_name = sys.argv[2]

marketplace_path.parent.mkdir(parents=True, exist_ok=True)
if marketplace_path.exists():
    data = json.loads(marketplace_path.read_text(encoding="utf-8-sig"))
else:
    data = {
        "name": "local-plugins",
        "interface": {
            "displayName": "Local Plugins",
        },
        "plugins": [],
    }

plugins = data.setdefault("plugins", [])
existing = None
for plugin in plugins:
    if plugin.get("name") == plugin_name:
        existing = plugin
        break

entry = {
    "name": plugin_name,
    "source": {
        "source": "local",
        "path": f"./plugins/{plugin_name}",
    },
    "policy": {
        "installation": "INSTALLED_BY_DEFAULT",
        "authentication": "ON_INSTALL",
    },
    "category": "Productivity",
}

if existing is None:
    plugins.append(entry)
else:
    existing.clear()
    existing.update(entry)

marketplace_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

printf '  Marketplace updated: %s\n' "${MARKETPLACE_PATH}"

printf '\n=== Installation Complete ===\n\n'
printf 'Next steps:\n'
printf '  1. Start a new Codex session\n'
printf '  2. Try: Use $codex-browser-agent to open example.com\n'
printf '  3. If a site needs login, complete it in the browser window once\n\n'
printf 'Plugin path: %s\n' "${PLUGIN_DIR}"
printf 'Profile path: %s\n' "${PROFILE_DIR}"
