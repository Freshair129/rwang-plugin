$ErrorActionPreference = "Stop"

$pluginRoot = Split-Path -Parent $PSScriptRoot
$scanner = Join-Path $pluginRoot "scripts\scan-annotations.ps1"
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("rwang-annotation-fixture-" + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    @'
// @req FR-001, NFR-002 — valid requirement links
// @req FR-a01001 — 5-driven atomic id (must match whole, never as FR-a01 or a flat FR-xxx)
// @spec SDD-004 — valid specification link
// @designs §5.5 — valid design section
// @tested __tests__/generation.test.ts::creates_generation
const prose = "@req FR-999 is only explanatory prose";
const another = "@tested annotations should not be scanned";
// This explanation mentions @spec SDD-777 but does not use annotation grammar.
// FR-003
'@ | Set-Content -LiteralPath (Join-Path $fixture "fixture.ts") -Encoding utf8

    @'
%% @id FEAT-a01:sequence
%% @req FR-a01001, FR-a01002
%% @spec FEAT-a01
%% @diagram_type sequence
%% this prose line mentions @req FR-888 but is not annotation grammar
sequenceDiagram
    actor Rider
    Rider->>Server: add_track
'@ | Set-Content -LiteralPath (Join-Path $fixture "fixture_sequence.mmd") -Encoding utf8

    @'
---
req: [FR-a01001, FR-a01002]
spec: FEAT-a01
test_type: TDD / Acceptance
---

# Test: Queue Management

Body text mentioning req: FR-777 must not be scanned after frontmatter.
'@ | Set-Content -LiteralPath (Join-Path $fixture "fixture_feature.test.md") -Encoding utf8

    @'
---
id: FEAT-a01
spec_format: EARS
---

# Feature: Queue Management

Body text with id: FR-777 after frontmatter must never be scanned.
'@ | Set-Content -LiteralPath (Join-Path $fixture "queue_management.md") -Encoding utf8

    $report = & $scanner -Path $fixture -Format json | ConvertFrom-Json
    if ($report.summary.structured_count -ne 13) { throw "Expected 13 structured annotations (5 code + 4 mmd + 3 test.md + 1 doc-id), got $($report.summary.structured_count)." }
    if ($report.summary.unstructured_count -ne 1) { throw "Expected 1 unstructured annotation, got $($report.summary.unstructured_count)." }
    $ids = @($report.summary.unique_ids)
    foreach ($expected in @("FR-001", "NFR-002", "SDD-004", "§5.5", "__tests__/generation.test.ts::creates_generation", "FR-003", "FR-a01001", "FR-a01002", "FEAT-a01", "FEAT-a01:sequence", "sequence", "TDD / Acceptance")) {
        if ($ids -notcontains $expected) { throw "Missing expected annotation value: $expected" }
    }
    foreach ($unexpected in @("FR-999", "SDD-777", "annotations", "FR-888", "FR-777", "FR-a01", "FR-010")) {
        if ($ids -contains $unexpected) { throw "Captured prose as an annotation: $unexpected" }
    }
    Write-Host "PASS: annotation grammar accepts code comments, .mmd annotations, and .test.md frontmatter; rejects prose."
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
