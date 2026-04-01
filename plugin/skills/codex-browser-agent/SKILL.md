---
name: codex-browser-agent
description: Browser automation for Codex through the Playwright MCP server bundled by the Codex Browser Agent plugin. Use when Codex needs to open a URL, inspect a webpage, browse an authenticated site through the saved browser profile, extract structured data from a page, click through a web app, fill forms, read feeds, upload files, or take screenshots. Always use this skill for browser tasks when the plugin's Playwright MCP tools are available.
---

# Codex Browser Agent

Use the Playwright MCP tools exposed by this plugin to control a real browser with a persistent profile.

## Verify Tools First

Before doing any browser task, confirm the Playwright MCP tools are available in the session. If they are missing, stop and tell the user the plugin was not loaded when this Codex session started.

Do not fall back to explaining limitations if the task is clearly about future setup. This plugin exists specifically to make future Codex sessions start with the browser tools already mounted.

## Default Workflow

1. Start from a clean tab state when the available tools support tab listing and closing.
2. Navigate to the target URL.
3. Wait briefly for the page to settle.
4. Prefer a DOM or accessibility snapshot first.
5. Use screenshots only when layout, images, or state verification matter.
6. Use evaluation for structured extraction when repeated content must be read at scale.

## Operating Rules

- Prefer DOM-aware inspection over screenshots for routine reading.
- Reuse the persistent profile for login state.
- If authentication is still required, ask the user to complete login manually in the browser window.
- For bulk extraction, use structured page evaluation instead of manually narrating repeated UI blocks.
- Before any irreversible action, restate exactly what will happen and ask for confirmation.

## Safety Rules

1. Never enter passwords, 2FA codes, payment details, or other secrets on the user's behalf.
2. Never post, publish, send, purchase, or submit anything irreversible without explicit confirmation.
3. Warn the user when the site appears suspicious or when automation may violate a site's policy.
4. Stop and ask the user to take over if the site requires CAPTCHA or other unexpected human verification.

## Common Patterns

### Read a Page

1. Navigate to the URL.
2. Wait for the main content to appear.
3. Capture a snapshot.
4. Summarize the visible content or extract the requested data.

### Read a Feed

1. Open the feed URL.
2. Let the page settle.
3. Use evaluation to extract repeated post objects with author, text, time, and engagement data.
4. Scroll only if the user asked for more.

### Fill a Form

1. Inspect the form fields first.
2. Fill fields carefully.
3. Show the populated state back to the user.
4. Stop before the final submit button unless the user explicitly confirms.

### Post or Send Content

1. Navigate to the compose surface.
2. Fill in the draft content.
3. Show the exact final content to the user.
4. Ask for explicit confirmation before clicking the final post or send button.
