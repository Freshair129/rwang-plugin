# RWANG (อาหวัง) — Document Intelligence System

A Claude Code plugin that brings SWE-standard documentation architecture, health checks, knowledge graphs, and implementation planning to any project.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **doc-architect** | `/rwang:doc-architect` | Analyze project → score templates → scaffold documentation structure |
| **doc-preflight** | `/rwang:doc-preflight` | Run 10-point health check: completeness, contradictions, staleness |
| **doc-graph** | `/rwang:doc-graph` | Build/update document graph, Change DAG, doc-code symlinks, traceability matrix |
| **implementation-plan** | `/rwang:implementation-plan` | Generate phase-by-phase roadmap with sprints, risks, milestones |
| **subagent-driven** | `/rwang:subagent-driven` | Orchestrate multi-step doc work: fresh subagent per task, review gate, fast iteration |

## Recommended Workflow

```
Manual workflow:
1. /rwang:doc-architect    → Set up doc structure for your project
2. [Write your docs]       → Fill in the scaffolded templates
3. /rwang:doc-preflight    → Check for gaps and contradictions
4. /rwang:doc-graph        → Build the knowledge graph and traceability
5. /rwang:implementation-plan → Generate the development roadmap

Automated workflow (subagent-driven):
1. /rwang:doc-architect    → Set up doc structure
2. /rwang:subagent-driven  → Dispatch fresh subagent per section,
                              review gate after each, final audit
3. /rwang:implementation-plan → Generate the roadmap
```

```mermaid
graph LR
    A[doc-architect] -->|scaffold| B[Write docs]
    B --> C[doc-preflight]
    C -->|fix issues| B
    C -->|pass| D[doc-graph]
    D --> E[implementation-plan]
    E --> F[Start building! 🚀]

    style A fill:#6D4AEF,color:#fff
    style C fill:#f59e0b,color:#fff
    style D fill:#14A88A,color:#fff
    style E fill:#2563eb,color:#fff
    style F fill:#059669,color:#fff
```

### Subagent-Driven Mode

```mermaid
graph LR
    A[doc-architect] --> S[subagent-driven]
    S -->|per section| W[Writer Agent]
    W --> R{Review Gate}
    R -->|FAIL| FX[Fix Agent]
    FX --> R
    R -->|PASS| N[Next Section]
    N -->|more| W
    N -->|done| AU[Final Audit]
    AU --> IP[implementation-plan]

    style S fill:#db2777,color:#fff
    style R fill:#f59e0b,color:#fff
    style AU fill:#14A88A,color:#fff
```

## Doc-Code Annotations

RWANG recognizes structured annotations in code comments:

```python
# @req FR-001, FR-002 — implements image generation pipeline
# @spec SDD-004 — agents use same pipeline API as UI
# @designs §5.5 — AI Agent Capabilities section
# @tested test_generation.py::test_create_generation
```

```typescript
// @req FR-001 — image generation endpoint
// @spec SDD-004 — same API surface for agents and UI
// @designs §5.5
// @tested __tests__/generation.test.ts
```

These annotations create bidirectional links in the document graph, enabling automatic traceability and drift detection.

## Document Templates

| Template | Best For |
|----------|----------|
| **Startup MVP** | ≤3 people, <50 files, no compliance |
| **3-Layer + Appendix** | 4-15 people, moderate complexity |
| **IEEE Full Split** | 15+ people, formal governance |
| **AI/ML Project** | Significant AI/ML components |
| **Regulated** | HIPAA / SOC2 / PCI / FDA compliance |
| **Microservices** | 3+ independent services |
| **Data Pipeline** | ETL-heavy, analytics platforms |

## Standards Supported

- **IEEE 29148-2018** — Systems and software engineering: Requirements
- **IEEE 1016-2009** — Software Design Description
- **ISO/IEC 42001** — AI Management System (for AI/ML projects)
- **IEEE 829-2008** — Software Test Plan (for IEEE Full Split)

## Git Hook

The plugin includes a drift-detection hook that warns when you edit code files tracked in the document graph:

```
[RWANG] Drift warning: 'backend/app/api/generations.py' is tracked in doc-graph.
[RWANG] Potentially affected docs: PRD-SDD-v2.0, API Reference
[RWANG] Run /rwang:doc-preflight to check for staleness.
```

## Scanner Scripts

Standalone scripts for CI/CD integration:

```powershell
# PowerShell (Windows)
.\scripts\scan-annotations.ps1 -Path "D:\GPIC" -Format table

# Bash (macOS/Linux/Git Bash)
./scripts/scan-annotations.sh /path/to/project table
```

## Installation

```bash
# Install as a local plugin
claude plugin add ./rwang-plugin
```

## Trust Hierarchy

When contradictions are detected between documents:

```
Code (what runs) > SDD (what was designed) > PRD (what was requested)
```

## File Structure

```
rwang-plugin/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/
│   ├── doc-architect/
│   │   └── SKILL.md             # Decision Engine skill
│   ├── doc-preflight/
│   │   └── SKILL.md             # Health check skill
│   ├── doc-graph/
│   │   └── SKILL.md             # Graph + DAG + symlinks skill
│   ├── implementation-plan/
│   │   └── SKILL.md             # Roadmap generation skill
│   └── subagent-driven/
│       └── SKILL.md             # Orchestrate via dispatch + review gate
├── hooks/
│   └── hooks.json               # PostToolUse drift detector
├── scripts/
│   ├── scan-annotations.ps1     # Annotation scanner (Windows)
│   ├── scan-annotations.sh      # Annotation scanner (Unix)
│   └── drift-check.ps1          # Drift detection hook script
├── references/
│   ├── templates.json           # Template definitions & scoring rules
│   └── doc-graph-schema.json    # JSON Schema for .doc-graph.json
└── README.md                    # This file
```

## License

MIT
