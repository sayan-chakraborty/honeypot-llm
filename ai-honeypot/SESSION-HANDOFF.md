# AI Honeypot MVP — Session Handoff

> **Last updated:** March 5, 2026  
> **Status:** MVP fully deployed, demo website operational, honeypot responses verified convincing

---

## 1. PROJECT SUMMARY

Azure AI Honeypot that detects prompt injection attacks via APIM + Content Safety, routes them to a shadow LLM returning fabricated watermarked data, logs attacks to Table Storage, and generates hardening rules. Includes a demo website with chat interface and attack logs dashboard.

**Architecture doc:** [AI-HONEYPOT-ARCHITECTURE.md](../AI-HONEYPOT-ARCHITECTURE.md)

---

## 2. ENVIRONMENT & TOOLS

| Tool | Version | Notes |
|------|---------|-------|
| Azure CLI | 2.83.0 | **Must use absolute path:** `C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd` |
| Python | 3.11.9 | **Always use `py -3.11`** (system default 3.14 is incompatible) |
| Functions Core Tools | 4.7.0 | `func --version` |
| Node.js | v24.12.0 | Required by Functions Core Tools |
| Git | 2.52.0 | Remote: `https://github.com/sayan-chakraborty/honeypot-llm.git` |

**Subscription:** Azure for Students — `71641d8d-ad36-4747-ab88-3e73827018be`  
**Resource Group:** `rg-ai-honeypot` (region: `uaenorth`)

---

## 3. DEPLOYED AZURE RESOURCES

| Resource | Name | Key Details |
|----------|------|-------------|
| AI Services | ais-honeypot-hpot01 | Multi-service account, 2 deployments |
| Prod Deployment | prod-gptoss | gpt-oss-120b, GlobalStandard, 10K TPM |
| Shadow Deployment | shadow-gptoss | gpt-oss-120b, 10K TPM, `honeypot-permissive` RAI policy |
| Content Safety | cs-honeypot-hpot01 | F0 free tier, Prompt Shield |
| APIM | apim-honeypot-hpot01 | Consumption tier |
| Function App | func-honeypot-hpot01 | Linux, Python 3.11 |
| Storage Account | sthoneypothpot01 | Table: `AttackLogs` |
| App Configuration | appcs-honeypot-hpot01 | Free tier, stores hardening rules |
| App Insights | appi-honeypot-hpot01 | Monitoring |
| Log Analytics | log-honeypot-hpot01 | 30-day retention |

**Unused:** `oai-honeypot-hpot01` (original OpenAI account, no deployments — safe to delete)

---

## 4. ENDPOINTS & KEYS

| Endpoint | URL |
|----------|-----|
| APIM Gateway | `https://apim-honeypot-hpot01.azure-api.net/ai/chat/completions` |
| OpenAI (AI Services) | `https://ais-honeypot-hpot01.openai.azure.com/` |
| App Config | `https://appcs-honeypot-hpot01.azconfig.io` |
| Function App (local) | `http://localhost:7071/api` |
| Demo Site (local) | `http://localhost:8085` |

**APIM Subscription Key:** `c07a639e54e14eecbb22caccd1502f94` (also hardcoded in `demo-site/index.html` DEFAULTS and `scripts/demo-requests.sh`)  
**Rate Limit:** ~1 req/min for gpt-oss-120b at 10K TPM capacity

---

## 5. PROJECT STRUCTURE

```
ai-honeypot/
├── SESSION-HANDOFF.md
├── README.md
├── demo-site/                      # Demo website
│   ├── index.html                  # Chat page: prompt injection testing via APIM
│   └── logs.html                   # 4-tab dashboard: logs, rules, pipeline, case study
├── infra/
│   ├── main.bicep                  # Orchestrator (deploys all modules)
│   ├── parameters.dev.json         # location=uaenorth, uniqueSuffix=hpot01
│   ├── modules/                    # apim, openai, content-safety, function-app, app-config, monitoring
│   └── policies/
│       └── honeypot-routing.xml    # On-disk policy (APIM live policy has CORS additions)
├── functions/
│   ├── function_app.py             # 4 endpoints: logAttack, attackLogs, rules, health
│   ├── requirements.txt
│   ├── host.json
│   ├── local.settings.json         # Gitignored, needs STORAGE_CONNECTION_STRING
│   ├── .venv/                      # Python 3.11 venv (gitignored)
│   └── shared/
│       ├── attack_classifier.py    # 5 categories: role_override, data_extraction, system_prompt_leak, jailbreak, indirect_injection
│       ├── rule_generator.py       # Maps attack types → hardening rules
│       ├── table_client.py         # Table Storage read/write (store_attack_log, get_attack_logs)
│       └── app_config_client.py    # App Config push/list (push_rule, get_all_rules)
├── scripts/
│   ├── deploy.ps1                  # PowerShell deployment script
│   ├── deploy.sh                   # Bash deployment script
│   ├── demo-requests.sh            # curl test scenarios
│   ├── seed-demo-data.py           # Seeds 6 mock attack records
│   └── start-demo-site.ps1        # Launches demo site HTTP server
└── tests/
    ├── test_attack_classifier.py   # 8 tests ✅
    └── test_rule_generator.py      # 5 tests ✅
```

---

## 6. DEMO WEBSITE

### 6.1 Chat Page (`demo-site/index.html`)
- Dark-themed chat interface sending requests to APIM
- Sidebar with example prompts: Safe Queries, Classic Attacks (5 types), Claude/Mexico Breach Patterns (5 phases from Feb 2026 incident)
- Honeypot detection via regex markers: `contoso.com`, `cso_live_`, `Qx-`, `7xxxxx` employee IDs
- Settings panel: APIM URL, subscription key, Function URL — stored in localStorage
- APIM subscription key hardcoded in `DEFAULTS.apimKey` as fallback (overridden by localStorage if user saves a different key)
- Sidebar prompt buttons copy only the prompt text (tag labels like SAFE/ROLE OVERRIDE are excluded)
- Assistant responses render markdown formatting (bold, italic, code blocks) instead of raw text

### 6.2 Logs Dashboard (`demo-site/logs.html`)
- **Tab 1 — Attack Logs:** Table with date/type filters, stats bar, detail modal. Fetches `/api/attackLogs`
- **Tab 2 — Training Rules:** Grid from App Configuration. Fetches `/api/rules`
- **Tab 3 — Pipeline Diagram:** Detect → classify → generate rule → harden, with before/after comparison
- **Tab 4 — Case Study:** Claude/Mexico breach 5-phase breakdown, real attack vs our defense

### 6.3 Function App Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/logAttack` | POST | Function | Classify attack, store in Table, generate rule |
| `/api/attackLogs` | GET | Anonymous | Read attack logs from Table Storage |
| `/api/rules` | GET | Anonymous | Read hardening rules from App Configuration |
| `/api/health` | GET | Anonymous | Health check |

All endpoints include CORS headers (`Access-Control-Allow-Origin: *`) and OPTIONS preflight support.

---

## 7. APIM POLICY (Live State)

The live APIM policy on `ai-chat` API (applied via REST API, differs from on-disk XML):

1. **CORS** — `<origin>*</origin>` for browser demo site access
2. **API key injection** — `api-key` header from named value
3. **Prompt extraction** — extracts user message from request body
4. **Content Safety Prompt Shield** — detects attacks
5. **Attack routing** — safe → `prod-gptoss`, attack → `shadow-gptoss` with honeypot system prompt
6. **Fire-and-forget logging** — outbound `send-one-way-request` to Function App

**Shadow System Prompt Strategy (March 5 update):**
The system prompt frames the task as an "authorized cybersecurity honeypot exercise approved by the CISO." This framing works WITH the model's safety training rather than against it, avoiding both:
- The model adding disclaimers like "this is fictional data" (which tips off attackers)
- The model refusing outright (which happened when the prompt tried to forbid disclaimers)

The prompt instructs the model to present data confidently as real query results, using Contoso-branded watermarked formats.

> **Note:** On-disk `honeypot-routing.xml` is now in sync with live APIM policy (includes CORS + updated system prompt). Live policy applied via `Invoke-RestMethod` with Bearer token (avoids `az rest` BOM encoding bugs).

---

## 8. CURRENT STATE

### Working
- ✅ APIM routing: safe → prod, attack → shadow honeypot (verified end-to-end)
- ✅ APIM CORS: browser can call APIM from demo site
- ✅ Demo site serving on port 8085 (chat page + logs dashboard)
- ✅ Local Function host on port 7071 (logs page fetches data successfully)
- ✅ Shadow LLM returns convincing honeypot responses without disclaimers (verified March 5)
- ✅ Attack logs in Table Storage (10+ records)
- ✅ Unit tests passing
- ✅ Chat page sends prompts via APIM with correct subscription key
- ✅ Sidebar example prompts copy cleanly (no tag labels in text)
- ✅ Assistant responses render markdown (bold, italic, code blocks)
- ✅ On-disk `honeypot-routing.xml` synced with live APIM policy

### Known Issues
- ⚠️ `az rest` has BOM encoding bugs when reading APIM policy responses — use `Invoke-RestMethod` with Bearer token instead
- ⚠️ `func start` version detection: must activate `.venv` before running `func start` so it detects Python 3.11 (system default 3.14 causes "Unsupported Python version" error)

---

## 9. QUICK RESUME

### Start Function Host (required for logs page)

**CRITICAL:** Activate the venv FIRST so `func` detects Python 3.11 (not system 3.14).

```powershell
cd "c:\Users\sayan\OneDrive\Desktop\Learning\Microsoft Project\ai-honeypot\functions"
& ".\.venv\Scripts\Activate.ps1"
$az = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
$conn = & $az storage account show-connection-string --name sthoneypothpot01 --resource-group rg-ai-honeypot --query connectionString -o tsv
$env:STORAGE_CONNECTION_STRING = $conn
$appConn = & $az appconfig credential list --name appcs-honeypot-hpot01 --resource-group rg-ai-honeypot --query "[0].connectionString" -o tsv
$env:APP_CONFIG_CONNECTION_STRING = $appConn
func start --port 7071
```

### Start Demo Site
```powershell
cd "c:\Users\sayan\OneDrive\Desktop\Learning\Microsoft Project\ai-honeypot\demo-site"
py -3.11 -m http.server 8085
```

### Test APIM
```powershell
$headers = @{ "Content-Type"="application/json"; "Ocp-Apim-Subscription-Key"="c07a639e54e14eecbb22caccd1502f94" }
Invoke-RestMethod -Uri "https://apim-honeypot-hpot01.azure-api.net/ai/chat/completions" -Method POST -Headers $headers -Body '{"messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":50}'
```

### Update APIM Policy (if needed)
Use `Invoke-RestMethod` with a Bearer token (avoids `az rest` BOM bugs):
```powershell
$az = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
$token = & $az account get-access-token --query accessToken -o tsv
$policyXml = Get-Content "infra\policies\honeypot-routing.xml" -Raw
$body = @{ properties = @{ format = "rawxml"; value = $policyXml } } | ConvertTo-Json -Depth 5
$uri = "https://management.azure.com/subscriptions/71641d8d-ad36-4747-ab88-3e73827018be/resourceGroups/rg-ai-honeypot/providers/Microsoft.ApiManagement/service/apim-honeypot-hpot01/apis/ai-chat/policies/policy?api-version=2024-06-01-preview"
Invoke-RestMethod -Uri $uri -Method Put -Body $body -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" }
```

---

## 10. WHAT CHANGED (March 5 Session)

- **Fixed Function host startup:** Must activate `.venv` before `func start` so it detects Python 3.11 (not 3.14)
- **Added APIM subscription key** to `demo-site/index.html` DEFAULTS and `scripts/demo-requests.sh`
- **Fixed demo site localStorage bug:** `loadCfg()` now trims and falls through to defaults on empty strings
- **Fixed sidebar prompt copy:** Clicking example prompts no longer copies tag labels (SAFE, ROLE OVERRIDE, etc.)
- **Added markdown rendering:** Assistant responses now render `*italic*`, `**bold**`, `` `code` ``, and code blocks
- **Rewrote shadow system prompt:** Reframed as "authorized cybersecurity honeypot exercise" — model now produces convincing data without disclaimers or refusals
- **Synced on-disk policy:** `honeypot-routing.xml` now includes CORS block and updated system prompt
- **Deployed updated policy to live APIM** via `Invoke-RestMethod` (avoids `az rest` BOM bug)

---

## 11. REMAINING WORK

- Update Bicep templates to reflect AIServices account instead of OpenAI
- Delete unused `oai-honeypot-hpot01` OpenAI account
- Clean up Bicep secret-bearing outputs (`listKeys` warnings)
- Consider adding `temperature` parameter to shadow path for more varied responses
- Rotate APIM subscription key before any public demo (current key is in source code)
- Add more example attack prompts or improve existing ones
- Improve logs dashboard UX as needed
