# Qwen + Claude Code Router (CCR) — Authentication & Token Refresh Tutorial

This guide shows how to use Qwen Code as a free provider for the Claude Code Router (CCR). It covers installation, initial OAuth authentication with the Qwen CLI, extracting the access token, configuring CCR, and the crucial token refresh workflow so you can keep using Qwen’s free tier for coding tasks.

Credit: method popularized by the community (thanks to Daniyal Hashmi).

---

## Table of Contents
- Prerequisites
- 1) Install Qwen Code CLI
- 2) Initial Authentication
- 3) Extract the Access Token
- 4) Configure Claude Code Router (CCR)
- 4a) Full example config.json (example file contents)
- 5) Refreshing the Token (when expired)
- Troubleshooting / Clean reset
- Windows-specific notes
- Security notes & tips
- Example: quick test curl
- FAQ

---

## Prerequisites
- Node.js installed.
- Claude Code Router (CCR) installed globally:
  ```bash
  npm install -g @musistudio/claude-code-router
  ```

---

## 1) Install Qwen Code CLI
Install the official Qwen CLI which performs OAuth for you:

```bash
npm install -g @qwen-code/qwen-code@latest
```

---

## 2) Initial Authentication
Open a terminal and run the Qwen CLI:

```bash
qwen
```

- If prompted, choose the Qwen OAuth option or type:
  ```
  /auth
  ```
- This will open your default browser. Log in with your Qwen / Alibaba Cloud account.
- When complete the CLI will confirm the login and write credentials locally.

---

## 3) Extract the Access Token
Qwen stores session credentials locally in a JSON file. You need the `access_token` string for CCR.

- File location:
  - macOS / Linux: `~/.qwen/oauth_creds.json`
  - Windows (PowerShell): `C:\Users\<YourUser>\.qwen\oauth_creds.json`

Open that file and copy the value of the `access_token` field (it's a long string).

Important: Treat this token like a secret. Do not share it.

Quick view / copy (Linux/macOS; requires jq):
```bash
jq -r '.access_token' ~/.qwen/oauth_creds.json
```

---

## 4) Configure Claude Code Router
Open your CCR config file (usually in your home directory):

Path:
- `~/.claude-code-router/config.json`

Add or update a provider entry for Qwen. Minimal example:

```json
{
  "name": "qwen",
  "api_base_url": "https://portal.qwen.ai/v1/chat/completions",
  "api_key": "PASTE_YOUR_ACCESS_TOKEN_HERE",
  "models": [
    "qwen-coder-plus"
  ],
  "transformer": {
    "use": ["qwen"]
  }
}
```

Notes:
- Make sure `models` includes a model that works with your free-tier access (e.g., `qwen-coder-plus`).
- `api_base_url` above is the typical endpoint for chat/completion — verify with Qwen docs if needed.

Save the file.

Restart CCR to pick up changes:

```bash
ccr stop
ccr start
```

Now you can code using CCR:

```bash
ccr code
```

---

## 4a) Full example config.json (example file contents)
Below is a more complete example of a typical `~/.claude-code-router/config.json` that some users have. It includes logging, server fields, and a Providers array that uses a Qwen provider entry. You can copy/paste this into your config file and replace the API key placeholder with the token from `~/.qwen/oauth_creds.json`.

(Note: this example shows one valid shape of CCR config — your installation may use a slightly different structure. Adjust accordingly.)

GNU nano 7.2                           /home/linux/.claude-code-router/config.json *
```json
{
  "LOG": true,
  "LOG_LEVEL": "info",
  "CLAUDE_PATH": "",
  "HOST": "127.0.0.1",
  "PORT": 3456,
  "APIKEY": "",
  "API_TIMEOUT_MS": "600000",
  "PROXY_URL": "",
  "transformers": [],
  "Providers": [
    {
      "name": "qwen",
      "api_base_url": "https://portal.qwen.ai/v1/chat/completions",
      "api_key": "Your API KEY Here",
      "models": [
        "qwen3-coder-plus"
      ]
    }
  ],
  "StatusLine": {
    "enabled": false,
    "currentStyle": "default",
    "default": {
      "modules": []
    }
  }
}
```

How to paste the token into this file:
1. Copy the access token:
   ```bash
   jq -r '.access_token' ~/.qwen/oauth_creds.json | xclip -selection clipboard   # (optional: copies to clipboard on Linux with xclip)
   ```
2. Open the config in an editor:
   ```bash
   nano ~/.claude-code-router/config.json
   ```
3. Replace "Your API KEY Here" (or the `api_key` value in your config) with the token string.
4. Save and exit (in nano: Ctrl+O, Enter, Ctrl+X).
5. Restart CCR:
   ```bash
   ccr stop && ccr start
   ```

---

## 5) Refreshing the Token (When Expired)
Qwen access tokens expire (you’ll see 401 errors). The refresh workflow is quick — you do NOT need to reinstall the CLI every time.

Steps:

1. Re-authenticate:
   ```bash
   qwen
   ```
   then type:
   ```
   /auth
   ```
   and complete the browser login. This writes a new token to `~/.qwen/oauth_creds.json`.

2. Get the new token:
   - Open `~/.qwen/oauth_creds.json` and copy the updated `access_token`.

3. Update CCR config:
   - Paste the new token into `~/.claude-code-router/config.json` replacing the old `api_key`.

   Quick one-liner that updates common config shapes (requires jq):
   - Top-level `api_key`:
     ```bash
     TOKEN=$(jq -r '.access_token' ~/.qwen/oauth_creds.json) && jq --arg t "$TOKEN" '.api_key=$t' ~/.claude-code-router/config.json > /tmp/ccr_config.json && mv /tmp/ccr_config.json ~/.claude-code-router/config.json
     ```
   - Provider inside `Providers` array (provider named "qwen"):
     ```bash
     TOKEN=$(jq -r '.access_token' ~/.qwen/oauth_creds.json) && jq --arg t "$TOKEN" '( .Providers[] | select(.name=="qwen") | .api_key ) = $t' ~/.claude-code-router/config.json > /tmp/ccr_config.json && mv /tmp/ccr_config.json ~/.claude-code-router/config.json
     ```

4. Restart CCR:
   ```bash
   ccr stop
   ccr start
   ```

5. Resume work:
   ```bash
   ccr code
   ```

That’s it — re-auth once, paste the new token, restart CCR.

---

## Troubleshooting / Clean reset
If refreshing fails (token corrupted, exhausted, or you want to force a fresh OAuth session), remove the local Qwen credentials and re-run auth.

macOS / Linux:
```bash
rm -rf ~/.qwen
# then re-authenticate
qwen
# then /auth and follow the steps above
```

Windows (PowerShell):
```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\.qwen
# then re-authenticate
qwen
# then /auth and follow the steps above
```

Windows (cmd.exe):
```cmd
rmdir /s /q "%USERPROFILE%\.qwen"
```

Warning: Deleting `~/.qwen` logs you out of all Qwen CLI sessions on that machine. Only do this if you understand that consequence.

After deleting, repeat steps in "Initial Authentication" and then update CCR with the fresh token.

---

## Windows-specific tips
- OAuth file: `C:\Users\<YourUser>\.qwen\oauth_creds.json`
- Removing credentials (PowerShell): `Remove-Item -Recurse -Force $env:USERPROFILE\.qwen`
- Removing credentials (cmd): `rmdir /s /q "%USERPROFILE%\.qwen"`

---

## Security notes & tips
- Do NOT commit `~/.qwen/oauth_creds.json` or your CCR config with `api_key` into version control.
- Treat the `access_token` as sensitive; rotate it if exposed.
- Consider storing the token in a secure secrets manager if you're using this on a server.
- The `rm -rf ~/.qwen` / Windows equivalent wipes local credentials — be careful and only use when necessary.

---

## Example: quick curl test (optional)
You can test the token directly with a simple curl to the Qwen chat/completions endpoint (replace <TOKEN> and model as needed):

```bash
curl -s -X POST "https://portal.qwen.ai/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{
    "model": "qwen-coder-plus",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 64
  }'
```

If you get a valid JSON response, the token is valid. If you get 401, re-run the refresh steps.

---

## FAQ

Q: Do I need to keep the Qwen CLI installed?
A: Yes — the CLI is the easiest way to perform OAuth and refresh tokens. You do not need to reinstall it for each token refresh.

Q: How often will tokens expire?
A: Token lifetimes are controlled by Qwen/Alibaba Cloud and can change. Expect to re-authenticate occasionally (hours to days).

Q: Can I automate token refresh?
A: Automating OAuth re-auth is possible but typically requires secure handling of credentials and a supported refresh flow. For most hackathon/student use-cases, manual refresh via the CLI is simplest.

---

## Credits
This workflow and community tips were popularized by members of the community — special thanks to Daniyal Hashmi for surfacing this technique for students and hackathon workflows.

---
