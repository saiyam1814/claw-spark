<p align="center">
  <img src="web/logo.svg" alt="clawspark" width="80" />
</p>

<h1 align="center">clawspark</h1>

<p align="center">
  <strong>One command. Private AI agent. Your hardware.</strong>
</p>

<p align="center">
  <a href="https://clawspark.dev">Website</a> &middot;
  <a href="docs/tutorial.md">Tutorial</a> &middot;
  <a href="docs/configuration.md">Configuration</a> &middot;
  <a href="#contributing">Contributing</a>
</p>

---

```bash
curl -fsSL https://clawspark.dev/install.sh | bash
```

That's it. Come back in 5 minutes to a fully working, fully private AI agent that can code, research, browse the web, analyze images, and manage your tasks. Everything runs on your hardware. No cloud APIs, no subscriptions, no telemetry.

## What is this?

[OpenClaw](https://github.com/openclaw/openclaw) is the most popular open-source AI agent (340K+ stars). **clawspark** gets it running on your NVIDIA hardware in one command. Fully local. Fully private. Your data never leaves your machine.

**What happens when you run it:**

1. Detects your hardware (DGX Spark, Jetson, RTX GPUs, Mac)
2. Picks the best model using [llmfit](https://github.com/AlexsJones/llmfit) for hardware-aware selection
3. Installs everything (Ollama, OpenClaw, 10 skills, dependencies)
4. Configures multi-model (chat + vision + optional image generation)
5. Enables voice (local Whisper transcription, zero cloud)
6. Sets up browser automation (headless Chromium)
7. Sets up your dashboard (chat UI + metrics)
8. Creates systemd services (auto-starts on boot)
9. Hardens security (firewall, auth tokens, localhost binding, Docker sandbox)

## Supported Hardware

| Hardware | Memory | Default Model | Tokens/sec |
|---|---|---|---|
| **DGX Spark** | 128 GB unified | Qwen 3.5 35B-A3B | ~59 (measured) |
| Jetson AGX Thor | 128 GB unified | Auto-selected | Community testing |
| Jetson AGX Orin | 64 GB unified | Auto-selected | Community testing |
| RTX 5090 / 4090 | 24-32 GB VRAM | Auto-selected | Community testing |
| RTX 4080 / 4070 | 8-16 GB VRAM | Auto-selected | Community testing |
| Mac M1/M2/M3/M4 | 16-128 GB unified | Auto-selected | Community testing |

NVIDIA platforms use [llmfit](https://github.com/AlexsJones/llmfit) to detect your hardware and pick the best model. macOS uses a curated fallback list.

## Quick Start

The installer asks 3 questions:

```
[1/3] Which model?         > 5 models ranked by hardware fit
[2/3] Messaging platform?  > WhatsApp / Telegram / Both / Skip
[3/3] Tailscale?           > Yes (remote access) / No
```

Zero interaction mode:

```bash
curl -fsSL https://clawspark.dev/install.sh | bash -s -- --defaults
```

## What Your Agent Can Do

| Capability | How it Works |
|---|---|
| **Answer questions** | Local LLM via Ollama |
| **Search the web** | Built-in web search + DuckDuckGo, no API key |
| **Deep research** | Sub-agents run parallel research threads |
| **Browse websites** | Headless Chromium (navigate, click, fill forms, screenshot) |
| **Analyze images** | Vision model for screenshots, photos, diagrams |
| **Write and run code** | exec + read/write/edit tools |
| **Voice notes** | Local Whisper transcription for WhatsApp voice messages |
| **File management** | Read, write, edit, search files on the host |
| **Scheduled tasks** | Cron-based automation |
| **Sub-agent orchestration** | Spawn parallel background agents |

All of this runs locally. No data leaves your machine.

## Skills

10 verified skills ship by default. Install curated bundles:

```bash
clawspark skills pack research      # Deep research + web search (4 skills)
clawspark skills pack coding        # Code generation + review (2 skills)
clawspark skills pack productivity  # Task management + knowledge (3 skills)
clawspark skills pack voice         # Voice interaction (2 skills)
clawspark skills pack full          # Everything (10 skills)
```

Manage individual skills:

```bash
clawspark skills add <name>         # Install a skill
clawspark skills remove <name>      # Remove a skill
clawspark skills sync               # Apply skills.yaml changes
clawspark skills audit              # Security scan installed skills
```

## Multi-Model

Three model slots:

| Slot | Purpose | Example |
|---|---|---|
| **Chat** | Conversation and coding | `ollama/qwen3.5:35b-a3b` |
| **Vision** | Image analysis | `ollama/qwen2.5-vl:7b` |
| **Image gen** | Create images (optional) | Local ComfyUI or API |

```bash
clawspark model list                # Show all models
clawspark model switch <model>      # Change chat model
clawspark model vision <model>      # Set vision model
```

## Security

- UFW firewall (deny incoming by default)
- 256-bit auth token for the gateway API
- Gateway binds to localhost only
- Code-level tool restrictions (21 blocked command patterns)
- SOUL.md + TOOLS.md with immutable guardrails
- Plugin approval hooks (user confirmation before acting)
- Optional Docker sandbox (no network, read-only root, all caps dropped)
- Air-gap mode: `clawspark airgap on`
- OpenAI-compatible API gateway for local-first workflows

**Skill security audit** -- scans installed skills for 30+ malicious patterns (credential theft, exfiltration, obfuscation). Protects against ClawHub supply chain attacks:

```bash
clawspark skills audit
```

## Diagnostics

Full system health check across hardware, GPU, Ollama, OpenClaw, skills, ports, security, and logs:

```bash
clawspark diagnose                  # alias: clawspark doctor
```

Generates a shareable debug report at `~/.clawspark/diagnose-report.txt`.

## CLI Reference

```
clawspark status              Show system health
clawspark start               Start all services
clawspark stop [--all]        Stop services (--all includes Ollama)
clawspark restart             Restart everything
clawspark update              Update OpenClaw, re-apply patches
clawspark benchmark           Run performance benchmark
clawspark model list|switch|vision   Manage models
clawspark skills sync|add|remove|pack|audit   Manage skills
clawspark sandbox on|off|status|test   Docker sandbox
clawspark tools list|enable|disable   Agent tools
clawspark mcp list|setup|add|remove   MCP servers
clawspark tailscale setup|status   Remote access
clawspark airgap on|off       Network isolation
clawspark diagnose            System diagnostics
clawspark logs                Tail gateway logs
clawspark uninstall           Remove everything
```

## Dashboard

Two web interfaces out of the box:

- **Chat UI**: `http://localhost:18789/__openclaw__/canvas/`
- **Metrics**: `http://localhost:8900` (ClawMetry)

Both bind to localhost. Use Tailscale for remote access.

## Docker Sandbox

Optional isolated code execution for sub-agents:

```bash
clawspark sandbox on          # Enable
clawspark sandbox off         # Disable
clawspark sandbox test        # Verify isolation
```

Containers run with no network, read-only root, all capabilities dropped, custom seccomp profile, and memory/CPU limits.

## Uninstall

```bash
clawspark uninstall
```

Removes all services, models, and config. Conversations preserved in `~/.openclaw/backups/` unless you pass `--purge`.

## Testing

73 tests using [bats](https://github.com/bats-core/bats-core):

```bash
bash tests/run.sh
```

| Suite | Tests | Coverage |
|---|---|---|
| `common.bats` | 27 | Logging, colors, helpers |
| `skills.bats` | 16 | YAML parsing, add/remove, packs |
| `security.bats` | 11 | Token generation, permissions, deny lists |
| `cli.bats` | 19 | Version, help, routing, error handling |

## Acknowledgements

- **[OpenClaw](https://github.com/openclaw/openclaw)** -- AI agent framework
- **[Ollama](https://ollama.com)** -- Local LLM inference
- **[llmfit](https://github.com/AlexsJones/llmfit)** -- Hardware-aware model selection
- **[Baileys](https://github.com/WhiskeySockets/Baileys)** -- WhatsApp Web client
- **[Whisper](https://github.com/openai/whisper)** -- Speech-to-text
- **[ClawMetry](https://github.com/vivekchand/clawmetry)** -- Observability dashboard
- **[Qwen](https://github.com/QwenLM/Qwen)** -- The model family that runs great on DGX Spark

## Maintainers

- **[Saiyam Pathak](https://github.com/saiyam1814)**
- **[Rohit Ghumare](https://github.com/rohitg00)**

## Contributing

PRs welcome. Areas where help is needed:

- Testing on Jetson variants and RTX GPUs
- Hardware detection for more GPU models
- Additional messaging platform integrations
- New skills and skill packs
- Sandbox improvements

## License

MIT. See [LICENSE](LICENSE).

---

<p align="center">
  Built for people who want AI that works for them, not the other way around.
  <br />
  <a href="https://clawspark.dev">clawspark.dev</a>
</p>
