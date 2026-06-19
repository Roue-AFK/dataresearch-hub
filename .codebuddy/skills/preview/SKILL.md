---
name: preview
description: Preview, deploy, or run a web project in the sandbox. Triggers on "预览", "preview", "看效果", "跑起来", "deploy", "give me a URL", "show me the page", etc.
allowed-tools: Read, Write, Bash
---

Launch a web server inside the sandbox environment and produce an accessible preview URL.

---

## ⛔ ABSOLUTE RULE — NEVER construct a preview URL yourself

> **This is the single most important rule in this skill. Violating it WILL produce a broken link.**

You MUST call the `notify` script to obtain the preview URL. The URL has a **precise, dynamic format** that depends on runtime environment variables you cannot reliably know or assemble.

**FORBIDDEN behaviors (violation = broken preview):**

- ❌ NEVER concatenate, interpolate, or guess any part of the base preview URL (scheme + domain + query params)
- ❌ NEVER read `$X_IDE_SPACE_KEY` or `$X_IDE_PREVIEW_DOMAIN` and build the URL yourself
- ❌ NEVER hardcode or assume any domain pattern (e.g. `e2b6.sandbox.*`, `*.e2b.*`, `e2b6.xxx`)
- ❌ NEVER invent a URL format based on memory or pattern-matching from training data
- ❌ NEVER modify, trim, or "fix" the domain or query parameters that `notify` outputs

**The ONLY correct action:** run `notify <port>`, read its stdout, and use that base URL. You MAY append a file path (e.g. `/demo.html`) to the URL if the user's project requires it, but the **domain and query parameters MUST come from `notify` exactly as printed**.

### Common WRONG URLs (for your awareness — NEVER produce these)

| Wrong URL | What went wrong |
|-----------|----------------|
| `https://webview.e2b6.sandbox.cloudstudio.club/?...` | Domain is fabricated — `e2b6` is NOT a valid subdomain |
| `https://webview.e2b6.sandbox.cloudstudio.club/demo.html?...` | Domain is fabricated — the `e2b6.sandbox` part does not exist |
| `https://webview.sandbox.cloudstudio.club/?...` | Domain is wrong — missing the correct region/cluster subdomain |
| `https://<anything-you-typed-instead-of-notify-output>` | Any base URL not from `notify` output is WRONG |

> The correct domain is **only known at runtime** (e.g. `webview.e2b.bj2.sandbox.cloudstudio.club`) and is produced solely by `notify`. The domain varies by region/cluster — **do not guess it**.

---

## When to activate

- User asks to preview a page or project ("预览", "preview", "看效果", "show me what it looks like")
- User asks to deploy and view ("部署", "deploy", "跑起来", "run it")
- After creating/modifying a web page, user wants to view it ("做好了吗", "let me preview it")
- User asks for an accessible link ("给我链接", "give me a URL")

**Rule**: if the user has a web artifact and expresses any desire to view/access it, activate this skill.

## Steps

### Step 0. Serving strategy

⚠️ **WebSocket is NOT proxied — NEVER use dev servers (`vite dev` / `next dev` / `webpack-dev-server`).**

| Type | Method |
|---|---|
| Static HTML | `python3 -m http.server <port>` |
| Vite / CRA / Vue CLI | `build` → static-serve `dist/` |
| Next.js | `next build && next start` |
| Custom server | Production mode (`node server.js`) |

- Entry must be `index.html` at root `/` (not `app.html` / `hello.html`).
- SPA: prefer **HashRouter** (`/#/path`); if BrowserRouter, add server fallback → `index.html`.

### Step 1. Start the server

Pick an available port (default to **8000**). If occupied, increment (8001, 8002, …).

Follow the strategy from Step 0. Install dependencies, build if needed, then start the server:

- **Bind to `0.0.0.0`**, not `localhost` or `127.0.0.1`.
- **Only kill processes on the specific port** — never use `killall` or `pkill`.
- **Before killing a port**, verify it's not a critical service (e.g. port 22/80/443).
- **Use `nohup`** so the server survives after the shell exits.

```bash
lsof -ti:<port> | xargs kill -9 2>/dev/null || true
nohup <start-command> > server.log 2>&1 &
sleep 3
```

If the server fails to start, inspect `server.log` and fix the issue before retrying.

### Step 2. Call `notify` to get the preview URL (REQUIRED — NO EXCEPTIONS)

> ⚠️ **REMINDER: You MUST NOT build the URL yourself. Only `notify` produces valid URLs.**

**Immediately after the server starts**, call `notify` for each port:

```bash
<this-skill-directory>/notify <port>
```

`notify` will:
1. Verify the port is listening (fails if not)
2. Build the correct preview URL using runtime environment variables
3. Signal the client to open a browser tab
4. **Output the URL on stdout** — this is your ONLY source of truth for the preview URL

**If `notify` fails** (port not listening), check `server.log` for errors, fix the issue, restart the server, and **call `notify` again**. Retry up to 3 times.

**NEVER skip this step. NEVER build the URL yourself. NEVER use `echo $X_IDE_SPACE_KEY` or `curl` to construct a URL — `notify` does all of this.**

### Step 3. Reply with the EXACT URL from `notify` output

> ⚠️ **The domain and query parameters MUST come directly from `notify`'s output. Do NOT modify, reformat, or replace them.**

`notify` outputs a JSON line like:
```
[Preview] {"port":"8000","url":"https://webview.e2b.bj2.sandbox.cloudstudio.club/?x-cs-sandbox-id=abc123&x-cs-sandbox-port=8000"}
```

Extract the `url` value from that JSON. This is your **base URL**.

- You MAY append a file path if the project needs it (e.g. add `/demo.html` to the URL path, before the `?`)
- You MUST NOT change the domain, scheme, or query parameters

Example (appending a path):
```
Base from notify: https://webview.e2b.bj2.sandbox.cloudstudio.club/?x-cs-sandbox-id=abc123&x-cs-sandbox-port=8000
With file path:   https://webview.e2b.bj2.sandbox.cloudstudio.club/demo.html?x-cs-sandbox-id=abc123&x-cs-sandbox-port=8000
```

Reply in **the same language the user used**. Examples:

If user spoke English:
```
[Click to preview](<URL>)

If the link above does not work, copy and paste this URL into your browser:
<URL>
```

If user spoke Chinese:
```
[点击预览](<URL>)

如果上方链接无法打开，请复制下方地址到浏览器访问：
<URL>
```

Always match the user's language — do NOT default to English.

**Final check before replying:**
- ✅ The domain in your URL is **identical** to what `notify` printed (e.g. `webview.e2b.bj2.sandbox.cloudstudio.club`)
- ✅ The query parameters (`x-cs-sandbox-id`, `x-cs-sandbox-port`) are unchanged from `notify` output
- ✅ You did NOT fabricate or guess any part of the domain (no `e2b6`, no made-up subdomains)
- ❌ If you cannot find `notify`'s output, **re-run `notify`** — do NOT guess the URL

---

## Bad Cases (common mistakes to avoid)

| # | Mistake | Why it breaks |
|---|---------|---------------|
| 1 | Forgot to call `notify`, fabricated URL | Domain is wrong → 404 or SSL error |
| 2 | Used `localhost:8000` in reply | Only reachable inside sandbox, not by user |
| 3 | URL path placed after `?` query params | Path treated as query string → file not found |
| 4 | Appended non-existent file path | 404 error (e.g. `/app.html` when only `index.html` exists) |
| 5 | Double slash in path (`//index.html`) | Path resolution error |
| 6 | Used `vite dev` / `next dev` for preview | HMR WebSocket fails → `$RefreshReg$` error or blank page |
| 7 | Used BrowserRouter without fallback | Webview query params break path matching → blank page |
| 8 | Entry file named `hello.html` / `app.html` | User expects root `/` access, not `/hello.html` |

---

## Self-Check (before replying with URL)

```bash
# Verify file exists and server responds
ls <project-dir>/<entry-file>
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/<entry-file>
```

| # | Check | Pass criteria |
|---|-------|---------------|
| 1 | Domain from `notify` output | Character-by-character match |
| 2 | Query params unchanged | `x-cs-sandbox-id` and `x-cs-sandbox-port` identical |
| 3 | File path before `?` | Format: `https://domain/path.html?params` |
| 4 | File actually exists | `ls` confirms presence |
| 5 | Server returns 200 | `curl` confirms accessible |
| 6 | No fabricated domain | You did NOT type/recall any part of domain |
| 7 | Response body non-empty | `curl -s http://localhost:<port>/ \| wc -c` > 100 |
| 8 | No dev server running | Process is static serve / production, NOT `vite` / `next dev` |

⛔ Do NOT reply with URL until all checks pass.
