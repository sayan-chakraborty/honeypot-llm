# AI Honeypot MVP — Session Handoff

> **Last updated:** March 1, 2026  
> **Status:** MVP fully deployed & demo website operational

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

**APIM Subscription Key:** `c07a639e54e14eecbb22caccd1502f94`  
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

> **Note:** On-disk `honeypot-routing.xml` does NOT include CORS. Live policy was applied via `az rest --method put`.

---

## 8. CURRENT STATE

### Working
- ✅ APIM routing: safe → prod, attack → shadow honeypot (verified)
- ✅ APIM CORS: browser can call APIM from demo site
- ✅ Demo site serving on port 8085
- ✅ Attack logs in Table Storage (10+ records)
- ✅ Unit tests passing

### Not Working / Pending
- ❌ Local Function host not running — logs page shows "Failed to fetch" (port 7071 down)
- ⚠️ Chat page untested from browser after CORS fix
- ⚠️ On-disk `honeypot-routing.xml` lacks CORS (out of sync with live policy)

---

## 9. QUICK RESUME

### Start Function Host (required for logs page)
```powershell
cd "c:\Users\sayan\OneDrive\Desktop\Learning\Microsoft Project\ai-honeypot\functions"
$az = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
$conn = & $az storage account show-connection-string --name sthoneypothpot01 --resource-group rg-ai-honeypot --query connectionString -o tsv
$env:STORAGE_CONNECTION_STRING = $conn
$appConn = & $az appconfig credential list --name appcs-honeypot-hpot01 --resource-group rg-ai-honeypot --query "[0].connectionString" -o tsv
$env:APP_CONFIG_CONNECTION_STRING = $appConn
$env:languageWorkers__python__defaultExecutablePath = "$PWD\.venv\Scripts\python.exe"
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

---

## 10. REMAINING WORK

- Start local Function host so logs page works
- End-to-end browser test of chat page (verify CORS fix)
- Sync on-disk `honeypot-routing.xml` with live APIM policy (add CORS block)
- Update Bicep templates to reflect AIServices account instead of OpenAI
- Delete unused `oai-honeypot-hpot01` OpenAI account
- Clean up Bicep secret-bearing outputs (`listKeys` warnings)
- Improve demo site styling/UX as needed
