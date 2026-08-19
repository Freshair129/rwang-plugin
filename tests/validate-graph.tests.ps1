# Acceptance tests for scripts/validate-graph.ps1 — mutation-based coverage of
# the RWG state matrix (CR-2026-08-20-01 A2 §2.9, test matrix §7).
# One golden fixture (tests/fixtures/mini-5driven) is copied per case and
# mutated to trigger exactly the failure under test.

$ErrorActionPreference = "Stop"

$pluginRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $pluginRoot "scripts\validate-graph.ps1"
$fixtureSrc = Join-Path $pluginRoot "tests\fixtures\mini-5driven"

$script:passed = 0
$script:failed = 0

function New-FixtureCopy {
    $dst = Join-Path ([System.IO.Path]::GetTempPath()) ("rwang-validate-fixture-" + [guid]::NewGuid())
    Copy-Item -LiteralPath $fixtureSrc -Destination $dst -Recurse
    # Stamp real semantic hashes (Mode=hash computes normalization per SPEC §2.3)
    $hashJson = & $validator -Root $dst -Mode hash | Out-String | ConvertFrom-Json
    $placeholder = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    foreach ($cf in (Get-ChildItem -Path (Join-Path $dst "docs\registry\edge-contracts") -File)) {
        $content = Get-Content -LiteralPath $cf.FullName -Raw
        $cid = ($content | Select-String -Pattern 'contract_id:\s*(\S+)').Matches[0].Groups[1].Value
        $real = $hashJson.$cid
        $content = $content.Replace($placeholder, $real)
        Set-Content -LiteralPath $cf.FullName -Value $content -Encoding utf8 -NoNewline
    }
    $graphPath = Join-Path $dst "docs\.doc-graph.json"
    $graph = Get-Content -LiteralPath $graphPath -Raw | ConvertFrom-Json
    foreach ($e in $graph.edges) {
        $e.semantic_hash = $hashJson.($e.contract_id)
    }
    $graph | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $graphPath -Encoding utf8
    return $dst
}

function Invoke-Validator([string]$Root) {
    $out = & $validator -Root $Root | Out-String
    return $out | ConvertFrom-Json
}

function Assert-Case {
    param(
        [string]$Name,
        [scriptblock]$Mutate,        # receives fixture root
        [string]$ExpectCode          # "" = expect ok
    )
    $tmp = New-FixtureCopy
    try {
        & $Mutate $tmp
        $result = Invoke-Validator $tmp
        if ($ExpectCode -eq "") {
            if ($result.ok) {
                Write-Host "PASS: $Name"
                $script:passed++
            } else {
                $codes = (@($result.findings) | ForEach-Object { $_.code }) -join ", "
                Write-Host "FAIL: $Name — expected ok, got findings: $codes"
                $script:failed++
            }
        } else {
            $codes = @($result.findings) | ForEach-Object { $_.code }
            if ($codes -contains $ExpectCode) {
                Write-Host "PASS: $Name ($ExpectCode)"
                $script:passed++
            } else {
                Write-Host "FAIL: $Name — expected $ExpectCode, got: $($codes -join ', ')"
                $script:failed++
            }
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}

function Edit-GraphJson([string]$Root, [scriptblock]$Change) {
    $p = Join-Path $Root "docs\.doc-graph.json"
    $g = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
    & $Change $g
    $g | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $p -Encoding utf8
}

function Edit-JsonFile([string]$FilePath, [scriptblock]$Change) {
    $o = Get-Content -LiteralPath $FilePath -Raw | ConvertFrom-Json
    & $Change $o
    $o | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $FilePath -Encoding utf8
}

# --- Happy path (golden fixture reconciles cleanly) ---------------------------

Assert-Case -Name "golden fixture passes all checks" -ExpectCode "" -Mutate { param($r) }

# --- Entity/registry states (RWG-101..107) -------------------------------------

Assert-Case -Name "T3 unregistered entity on filesystem" -ExpectCode "RWG-101" -Mutate {
    param($r)
    Edit-JsonFile (Join-Path $r "discovery.json") {
        param($d)
        $d.entities += [pscustomobject]@{ id = "feat:FEAT-x99"; path = "docs/domains/DOM-01--playback/specs/FEAT-x99--ghost.md" }
    }
}

Assert-Case -Name "T4 orphaned registry entry (file deleted)" -ExpectCode "RWG-102" -Mutate {
    param($r)
    Edit-JsonFile (Join-Path $r "discovery.json") {
        param($d)
        $d.entities = @($d.entities | Where-Object { $_.id -ne "feat:FEAT-a01" })
    }
    # keep the graph consistent with discovery loss? No — the point is registry
    # says it exists, filesystem says it doesn't.
}

Assert-Case -Name "T1 stale graph after merge (entity in registry+fs, not in graph)" -ExpectCode "RWG-103" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        $g.nodes = @($g.nodes | Where-Object { $_.id -ne "feat:FEAT-a01" })
        $g.edges = @($g.edges | Where-Object { $_.from -ne "feat:FEAT-a01" -and $_.to -ne "feat:FEAT-a01" })
    }
}

Assert-Case -Name "graph node without registry backing" -ExpectCode "RWG-104" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        $g.nodes += [pscustomobject]@{ id = "dom:DOM-99"; type = "domain"; label = "Ghost"; status = "current" }
    }
}

Assert-Case -Name "traceability projection out of sync" -ExpectCode "RWG-105" -Mutate {
    param($r)
    Edit-JsonFile (Join-Path $r "traceability.json") {
        param($t)
        $t.requirements = @()
    }
}

Assert-Case -Name "T2 duplicate entity ID across registry files" -ExpectCode "RWG-106" -Mutate {
    param($r)
    Copy-Item -LiteralPath (Join-Path $r "docs\registry\entities\domains\DOM-01.yaml") `
        -Destination (Join-Path $r "docs\registry\entities\domains\DOM-01-branch-copy.yaml")
}

Assert-Case -Name "T13 agent registry mutation without approval_ref" -ExpectCode "RWG-107" -Mutate {
    param($r)
    $p = Join-Path $r "docs\registry\entities\domains\DOM-01.yaml"
    (Get-Content -LiteralPath $p -Raw).Replace("actor_type: human", "actor_type: agent") |
        Set-Content -LiteralPath $p -Encoding utf8 -NoNewline
}

# --- Contract states (RWG-201..209) ----------------------------------------------

Assert-Case -Name "T5 uncontracted edge (no contract_id)" -ExpectCode "RWG-201" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        ($g.edges | Where-Object { $_.type -eq "visualized_by" }).contract_id = ""
    }
}

Assert-Case -Name "T5/T7 unknown predicate (provisional alias 'visualizes')" -ExpectCode "RWG-202" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        ($g.edges | Where-Object { $_.type -eq "visualized_by" }).type = "visualizes"
    }
}

Assert-Case -Name "T10 document-sourced implements (BikeOps false-green case)" -ExpectCode "RWG-203" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        ($g.edges | Where-Object { $_.type -eq "implements" }).from = "doc:PRD.md"
    }
}

Assert-Case -Name "T6 edge validated against wrong contract_version" -ExpectCode "RWG-204" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        ($g.edges | Where-Object { $_.type -eq "contains" }).contract_version = "0.9.0"
    }
}

Assert-Case -Name "T6 contract changed without new version (semantic diff)" -ExpectCode "RWG-205" -Mutate {
    param($r)
    $p = Join-Path $r "docs\registry\edge-contracts\visualized_by@1.0.0.yaml"
    (Get-Content -LiteralPath $p -Raw).Replace("cardinality: 0..*", "cardinality: 1..*") |
        Set-Content -LiteralPath $p -Encoding utf8 -NoNewline
}

Assert-Case -Name "T17 duplicated inverse edge" -ExpectCode "RWG-206" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        $orig = $g.edges | Where-Object { $_.type -eq "contains" }
        $g.edges += [pscustomobject]@{
            from = $orig.to; to = $orig.from; type = "contains"
            contract_id = $orig.contract_id; contract_version = $orig.contract_version
            semantic_hash = $orig.semantic_hash; status = "current"; source = "manual"
        }
    }
}

Assert-Case -Name "edge without assertion source" -ExpectCode "RWG-207" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        ($g.edges | Where-Object { $_.type -eq "defines" }).source = ""
    }
}

Assert-Case -Name "T19 duplicate manifest assertion" -ExpectCode "RWG-208" -Mutate {
    param($r)
    $dup = Join-Path $r "docs\domains\DOM-01--playback\specs"
    New-Item -ItemType Directory -Path $dup -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $r "docs\domains\DOM-01--playback\manifest.yaml") `
        -Destination (Join-Path $dup "manifest.yaml")
}

Assert-Case -Name "T20 manifest citing outdated contract_version" -ExpectCode "RWG-209" -Mutate {
    param($r)
    $p = Join-Path $r "docs\domains\DOM-01--playback\manifest.yaml"
    (Get-Content -LiteralPath $p -Raw).Replace("contract_version: 1.0.0", "contract_version: 0.5.0") |
        Set-Content -LiteralPath $p -Encoding utf8 -NoNewline
}

# --- Provenance neutrality (T14: identity unaffected by session) -----------------

Assert-Case -Name "T14 different session provenance still reconciles" -ExpectCode "" -Mutate {
    param($r)
    Edit-GraphJson $r {
        param($g)
        $g.provenance.actor_id = "another-agent"
        $g.provenance | Add-Member -NotePropertyName session_id -NotePropertyValue "totally-different-session" -Force
        $g.generated_at = "2026-08-21T09:00:00Z"
    }
}

# --- Summary ----------------------------------------------------------------------

Write-Host ""
Write-Host "=== validate-graph tests: $script:passed passed, $script:failed failed ==="
if ($script:failed -gt 0) { exit 1 } else { exit 0 }
