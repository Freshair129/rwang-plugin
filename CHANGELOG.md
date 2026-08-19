# Changelog

All notable changes to the RWANG plugin. Versions follow semver; the
`version` field in `.claude-plugin/plugin.json` is the update signal for
marketplace installs.

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
