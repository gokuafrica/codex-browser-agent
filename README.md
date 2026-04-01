# Codex Browser Agent

Give Codex agents a real browser through Playwright MCP, with a persistent user profile that keeps site sessions across runs.

This repository is the Codex equivalent of `claude-browser-agent`, but the installation model is different:

- Claude needed a Claude skill plus `claude mcp add ...`
- Codex needs a plugin bundle, a local `.mcp.json`, and a home marketplace entry so future sessions start with the browser tools available

That difference matters. A skill alone is not enough.

## Easiest Way to Install

Point a Codex agent at this repository and ask it to install:

```text
Clone https://github.com/gokuafrica/codex-browser-agent and install it
```

Or run the installer yourself.

### Windows

```powershell
git clone https://github.com/gokuafrica/codex-browser-agent.git
cd codex-browser-agent
powershell -ExecutionPolicy Bypass -File install.ps1
```

### macOS / Linux

```bash
git clone https://github.com/gokuafrica/codex-browser-agent.git
cd codex-browser-agent
bash install.sh
```

After installation, start a new Codex session.

## What It Installs

The installer writes three things into the user's home directory:

1. A plugin bundle at `~/plugins/codex-browser-agent`
2. A local marketplace entry at `~/.agents/plugins/marketplace.json`
3. A plugin-local Playwright MCP config pointing at `@playwright/mcp`

The plugin bundles a skill named `codex-browser-agent`. In a fresh Codex session, agents can either use that skill explicitly or just ask for browser automation naturally.

## How It Works

```text
You -> Codex session -> Codex plugin -> Playwright MCP -> Browser -> Website
```

- Browser state persists in `~/.playwright-mcp-profile`
- The installer prefers the browser already associated with that profile
- If no prior profile exists, the installer picks an installed browser and configures the plugin accordingly

## What Agents Should Learn From This Repo

If a Codex agent reads this repository, the intended lesson is:

1. A running Codex session cannot retroactively gain new MCP tools just because a skill mentions them
2. Future sessions can gain those tools by installing a plugin that exposes `.mcp.json`
3. The skill belongs inside the plugin so the browser tools and the instruction layer travel together

That is the setup pattern this repo demonstrates.

## Usage After Install

In a fresh Codex session, either say:

```text
Use $codex-browser-agent to open x.com and show me my feed
```

or just ask naturally:

```text
Open reddit.com and summarize the top posts
```

## Manual Setup

If you do not want to run the installer, manually create:

- `~/plugins/codex-browser-agent/.codex-plugin/plugin.json`
- `~/plugins/codex-browser-agent/.mcp.json`
- `~/plugins/codex-browser-agent/skills/codex-browser-agent/SKILL.md`
- `~/.agents/plugins/marketplace.json` with a local plugin entry

The plugin should launch:

```json
{
  "mcpServers": {
    "playwright": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@playwright/mcp@latest",
        "--browser",
        "msedge",
        "--user-data-dir",
        "C:\\Users\\<user>\\.playwright-mcp-profile"
      ]
    }
  }
}
```

Use the browser that matches the persistent profile on that machine.

## Limitations

- CAPTCHA and 2FA still need a human in the browser window
- Some sites block automation
- Existing sessions only load the plugin set they started with, so always test from a fresh Codex session after install

## Repository Layout

- `plugin/`
  - the plugin bundle copied into `~/plugins/codex-browser-agent`
- `install.ps1`
  - Windows installer
- `install.sh`
  - macOS/Linux installer

## License

MIT
