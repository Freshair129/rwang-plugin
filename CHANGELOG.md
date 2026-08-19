# Changelog

All notable changes to the RWANG plugin. Versions follow semver; the
`version` field in `.claude-plugin/plugin.json` is the update signal for
marketplace installs.

## [1.1.1] — 2026-08-20

Implements SPEC-5DRIVEN-01 Revision A3 (rename/alias/prefix-collision rules), driven by the BikeOps migration's `DOM-01--` → `DOM-a--` folder-rename proposal.

### Added
- Validator: alias support in reconciliation — adapter inputs (discovery/traceability) may reference `aliases`; Core resolves them to primary IDs. The canonical graph must contain primary IDs only.
- Validator collision checks (all `RWG-106`): alias vs entity_id / alias vs alias, duplicate `canonical_path`, and **prefix-ambiguous IDs** in name-based namespaces (`dom:`, `feat:`, `req:`, `rel:`) — e.g. `dom:DOM-01` vs `dom:DOM-011`.
- Test suite: 4 new mutation cases (22 total) + scanner boundary test (`FR-001` never matches inside `FR-a01001`).

### Clarified (SPEC §2.1, A3)
- Folder renames change `canonical_path` only — stable IDs never derive from folder names; the domain letter in `FR-a01001` is naming convention, membership comes from `parent_domain_id`.
- Changing a stable ID is a migration: new entry aliases the old ID.

## [1.1.0] — 2026-08-20

Implements [CR-2026-08-20-01 (A2, approved)](docs/cr/CR-2026-08-20-01-diagram-test-and-5driven-traceability.md).

### Breaking — graph schema 2.0.0
- Node `id` pattern gains `dom:`, `feat:`, `diag:`, `testspec:`, `rel:` prefixes; requirement IDs are namespaced (`req:<ns>:<ID>`).
- New node types: `domain`, `feature`, `diagram`, `test_spec`, `release`.
- Edge predicate `stale` **removed** — staleness is `status: "stale"` on the semantic edge.
- Every edge now requires `contract_id`, `contract_version`, `semantic_hash`.
- Graph header requires `source_ref` + `provenance`; single writer (`rwang:doc-graph`).
- `implements` edges must originate from `code_file` nodes; generated artifacts are never evidence sources.
- Graphs written against schema 1.x are readable in explicit `legacy` mode only.

### Added
- Closed-world Entity Registry (`docs/registry/`): `entity-types.yaml`, entity entries with lifecycle status + provenance, versioned Edge Contracts.
- Normative schemas: `references/entity-registry-schema.json`, `edge-contract-schema.json`, `profile-schema.json`, `node-manifest-schema.json`.
- View profiles with explicit `required` / `optional` / `not_applicable` declarations; reference profiles in `references/profiles/` (`5-driven-domain`, `flat-prd-sdd`, `ieee-full`, `microservices`).
- Node manifests (outgoing edge assertions only; no upstream/downstream file pairs).
- New canonical predicates: `contains`, `defines`, `guides`, `visualized_by`, `verified_by`, `refines`, `supersedes` (dual-label, single edge), `applies_to` (release binding, profile-gated).
- Core validator `scripts/validate-graph.ps1`: contract validation + exact-set reconciliation (`RWG-101..108`, `RWG-201..209`), semantic-hash normalization (`-Mode hash`), no-VCS mode via content-digest `source_ref`.
- Acceptance fixture `tests/fixtures/mini-5driven/` + mutation suite `tests/validate-graph.tests.ps1` (18 cases).
- Scanner support for `.mmd` (`%% @req` / `%% @spec` / `%% @diagram_type`), `.test.md` frontmatter, and 5-driven IDs (`FR-a01001`, `FEAT-a01`) in both `.ps1` and `.sh`.
- `doc-preflight` Checks #11–#16; profile-owned trust hierarchy.

### Changed
- `doc-graph` skill: registry-first process, validate-then-project (Hybrid IR), exact-set reconciliation gate, manual edges must pass contract validation, incremental updates only when reconciled.
- `doc-architect` skill: generates Registry/Contracts/manifests before scaffolding; never writes the graph itself.
- Coverage stats are `{covered, total}` ID-set counts, never percentage strings.

## [1.0.2] — 2026-08

- Codex adapter (`.codex-plugin/plugin.json`) and `rwang-self-audit` skill.
- Annotation-grammar hardening in `scan-annotations.ps1` (comments only, prose rejected) + test suite.

## [1.0.0] — 2026-08

- Initial release: `doc-architect`, `doc-preflight`, `doc-graph`, `implementation-plan`, `subagent-driven` skills; drift-check hook; annotation scanners.
