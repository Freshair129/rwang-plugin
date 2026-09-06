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

    # --- namespaced ids ---------------------------------------------------------------------
    # A project that prefixes its ids does so because its FR-009 is not the flat FR-009. Reading
    # ZPP-FR-009 as FR-009 does not lose a prefix, it names a different requirement.
    @'
// @req ZPP-FR-009 — namespaced id on an annotation
// @req TAX-NFR-001, RAG-OPS-001 — two namespaced ids on one line
// @spec AI-AGT-001 — a kind that already carried a dash
// @req FR-001, NFR-002 — flat ids still work
// RAG-GR-004
'@ | Set-Content -LiteralPath (Join-Path $fixture "namespaced.ts") -Encoding utf8

    # A skip list names directories. Substring-matching the whole path made "build" swallow this
    # file, and it was never reported as skipped — it simply produced nothing.
    @'
// @req SDD-005 — a file whose NAME contains a skip-list word
'@ | Set-Content -LiteralPath (Join-Path $fixture "builder.ts") -Encoding utf8

    # One unrecognised id in a list must not discard the recognised ones alongside it.
    @'
// @spec FR-093, ADR-058 — ADR is not an enumerated kind; FR-093 still is
'@ | Set-Content -LiteralPath (Join-Path $fixture "mixed.ts") -Encoding utf8

    $report2 = & $scanner -Path $fixture -Format json | ConvertFrom-Json
    $ids2 = @($report2.summary.unique_ids)

    foreach ($expected in @("ZPP-FR-009", "TAX-NFR-001", "RAG-OPS-001", "AI-AGT-001", "RAG-GR-004", "FR-093")) {
        if ($ids2 -notcontains $expected) { throw "Namespaced/mixed id not captured: $expected" }
    }
    # The truncation this guards against: none of these ids exists, each is the tail of one above.
    foreach ($forbidden in @("FR-009", "NFR-001", "OPS-001", "GR-004", "AGT-001")) {
        if ($ids2 -contains $forbidden) { throw "Matched inside a namespaced id, minting $forbidden" }
    }
    if ($ids2 -notcontains "SDD-005") { throw "builder.ts was skipped because its name contains a skip-list word" }
    Write-Host "PASS: namespaced ids are captured whole; skip list matches directories, not filename substrings."

    # --- the two scanners must agree -------------------------------------------------------
    # scan-annotations.sh is the same tool for another platform. When they disagree, a graph built
    # on one machine differs from the same graph built on another, and neither is wrong locally.
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) {
        $shScanner = Join-Path $pluginRoot "scripts/scan-annotations.sh"
        $shOut = & $bash.Source $shScanner $fixture 2>$null | Out-String
        $shReport = $shOut | ConvertFrom-Json
        # Compare like with like: the ps1 report's unique_ids also holds @designs sections and
        # @tested file references, which the sh report never counts. Only the requirement ids are
        # common ground, and they are what a graph is built from.
        $reqShape = '^([A-Z][A-Z0-9]{1,4}-[A-Z]{2,4}-\d{3}|FR-[a-z]\d{5}|FEAT-[a-z]\d{2}|(FR|NFR|SDD|SEC|AI-AGT|AI-ETH|BR|AC|DR|IR)-\d{3})$'
        $psReqIds = @($ids2 | Where-Object { $_ -match $reqShape })
        if ($shReport.summary.unique_req_ids -ne $psReqIds.Count) {
            throw "Scanner disagreement: ps1 found $($psReqIds.Count) requirement ids, sh found $($shReport.summary.unique_req_ids)."
        }
        if ($shReport.summary.structured_count -ne $report2.summary.structured_count) {
            throw "Scanner disagreement: ps1 found $($report2.summary.structured_count) structured, sh found $($shReport.summary.structured_count)."
        }
        Write-Host "PASS: scan-annotations.ps1 and scan-annotations.sh agree on the same tree."

        # A tree with no annotations is a valid answer. Under `set -euo pipefail` the sh scanner
        # used to exit on the grep that found nothing and print no report at all; the count it
        # would have printed was a doubled zero, because `grep -c .` both prints 0 and fails.
        $emptyDir = Join-Path $fixture "empty-subtree"
        New-Item -ItemType Directory -Path $emptyDir | Out-Null
        $emptyOut = & $bash.Source $shScanner $emptyDir 2>$null | Out-String
        if ([string]::IsNullOrWhiteSpace($emptyOut)) { throw "sh scanner produced no report for a tree with no annotations." }
        $emptyReport = $emptyOut | ConvertFrom-Json
        if ($emptyReport.summary.unique_req_ids -ne 0) { throw "Expected 0 ids for an empty tree, got $($emptyReport.summary.unique_req_ids)." }
        Write-Host "PASS: an annotation-free tree yields an empty report rather than a crash."
    } else {
        Write-Host "SKIP: bash not available; cross-scanner parity not checked."
    }
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
