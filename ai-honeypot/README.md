# AI Honeypot MVP

An AI-powered honeypot system built on Azure that detects prompt injection/jailbreak attacks at the API gateway level, silently reroutes malicious requests to a shadow LLM that returns plausible but fabricated data, captures attack telemetry, and generates hardening rules — all transparently to the attacker.

## Architecture

```
Client → Azure APIM (Consumption) → Content Safety Prompt Shield
                                         ├── SAFE → prod-gptoss (gpt-oss-120b)
                                         └── RISKY → shadow-gptoss (gpt-oss-120b + permissive RAI policy)
                                                       → Azure Function → Table Storage
                                                                        → App Configuration
```

> **Note:** Uses `gpt-oss-120b` via Azure AI Services instead of GPT-4o due to
> zero GPT inference quota on Azure for Students subscriptions. The model is
> OpenAI API-compatible and produces equivalent results.

## Project Structure

```
ai-honeypot/
├── infra/                    # Bicep infrastructure-as-code
│   ├── main.bicep            # Orchestrator
│   ├── parameters.dev.json   # Dev parameters
│   ├── modules/              # Individual resource modules
│   └── policies/             # APIM routing policy XML
├── functions/                # Azure Functions (Python v2)
│   ├── function_app.py       # Main entry point
│   ├── shared/               # Shared modules
│   │   ├── attack_classifier.py
│   │   ├── rule_generator.py
│   │   ├── table_client.py
│   │   └── app_config_client.py
│   ├── requirements.txt
│   └── host.json
├── scripts/                  # Deployment & demo scripts
│   ├── deploy.sh / deploy.ps1
│   ├── demo-requests.sh
│   └── seed-demo-data.py
└── tests/                    # Unit tests
```

## Prerequisites

- [Azure CLI](https://aka.ms/installazurecliwindows) (v2.50+)
- [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local) (v4)
- [Python 3.11](https://www.python.org/downloads/) (required by Azure Functions)
- [Node.js](https://nodejs.org/) (for installing Functions Core Tools)
- Azure subscription with ~$100 credits

## Quick Start

```bash
# 1. Login to Azure
az login

# 2. Deploy everything (infrastructure + function code)
./scripts/deploy.sh          # Linux/macOS/Git Bash
# or
.\scripts\deploy.ps1        # PowerShell on Windows

# 3. Seed demo data
python scripts/seed-demo-data.py

# 4. Run demo scenarios
./scripts/demo-requests.sh
```

## Estimated Monthly Cost

| Service | Tier | Cost |
|---------|------|------|
| APIM | Consumption | ~$0 |
| Azure AI Services (prod) | gpt-oss-120b | ~$1-3 |
| Azure AI Services (shadow) | gpt-oss-120b | ~$0.10-0.50 |
| Content Safety | F0 Free | $0 |
| Azure Functions | Consumption | $0 |
| Storage Account | LRS | ~$0.50 |
| App Configuration | Free | $0 |
| **Total** | | **~$2-4/month** |

## Running Tests

```bash
python tests/test_attack_classifier.py
python tests/test_rule_generator.py
```

## Demo Website (Single-Terminal Walkthrough)

This project includes a local website that presents the full step-by-step demo flow with copyable PowerShell commands.

```powershell
# From ai-honeypot root
.\scripts\start-demo-site.ps1
```

- Default URL: `http://localhost:8085`
- Optional custom port: `.\scripts\start-demo-site.ps1 -Port 8090`
- Optional no auto-open browser: `.\scripts\start-demo-site.ps1 -NoOpen`

The page includes:
- Azure session and deployment verification
- Local function host startup and endpoint tests
- APIM safe vs attack request tests
- Table Storage log verification

## Key Components

- **APIM Routing Policy**: Intercepts all requests, calls Content Safety Prompt Shield, routes safe requests to production and attacks to the honeypot
- **Shadow LLM**: gpt-oss-120b with a fabrication-tuned system prompt that generates realistic but fake data with embedded watermarks (uses custom `honeypot-permissive` RAI policy with jailbreak blocking disabled)
- **Attack Classifier**: Regex-based detection categorizing attacks into role override, data extraction, system prompt leak, jailbreak, and indirect injection
- **Rule Generator**: Automatically creates hardening rules from detected attack patterns
- **Table Storage**: Stores full attack transcripts for analysis
- **App Configuration**: Stores generated hardening rules that can be consumed by production systems
