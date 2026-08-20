# Acceptance tests for scripts/validate-plan.ps1 - mutation-based coverage of
# the PLN-1xx codes against the zuri-v2 execution-mode catalog.

$ErrorActionPreference = "Stop"

$pluginRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $pluginRoot "scripts\validate-plan.ps1"
$fixtureSrc = Join-Path $pluginRoot "tests\fixtures\plan-envelope\sample-plan.json"

$script:passed = 0
$script:failed = 0

function Assert-PlanCase {
    param(
        [string]$Name,
        [scriptblock]$Mutate,        # receives the plan object; mutate in place
        [string]$ExpectCode          # "" = expect ok
    )
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rwang-plan-" + [guid]::NewGuid() + ".json")
    try {
        $plan = Get-Content -LiteralPath $fixtureSrc -Raw | ConvertFrom-Json
        & $Mutate $plan
        $plan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $tmp -Encoding utf8
        $result = & $validator -PlanPath $tmp | Out-String | ConvertFrom-Json
        if ($ExpectCode -eq "") {
            if ($result.ok) { Write-Host "PASS: $Name"; $script:passed++ }
            else {
                $codes = (@($result.findings) | ForEach-Object { $_.code }) -join ", "
                Write-Host "FAIL: $Name - expected ok, got: $codes"; $script:failed++
            }
        } else {
            $codes = @($result.findings) | ForEach-Object { $_.code }
            if ($codes -contains $ExpectCode) { Write-Host "PASS: $Name ($ExpectCode)"; $script:passed++ }
            else { Write-Host "FAIL: $Name - expected $ExpectCode, got: $($codes -join ', ')"; $script:failed++ }
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}

Assert-PlanCase -Name "golden PlanEnvelope passes preflight" -ExpectCode "" -Mutate { param($p) }

Assert-PlanCase -Name "unknown execution mode" -ExpectCode "PLN-101" -Mutate {
    param($p)
    $p.workstreams[0].executionMode = "VIBE_CODING"
}

Assert-PlanCase -Name "progressStrategy disagrees with mode" -ExpectCode "PLN-102" -Mutate {
    param($p)
    $p.workstreams[0].progressStrategy = "SLA_SCORE"
}

Assert-PlanCase -Name "executionModeId disagrees with catalog" -ExpectCode "PLN-102" -Mutate {
    param($p)
    $p.workstreams[0].executionModeId = "EXM-OPERATIONS"
}

Assert-PlanCase -Name "container subtype foreign to mode" -ExpectCode "PLN-103" -Mutate {
    param($p)
    $p.workstreams[0].containers[0].subtype = "CAMPAIGN"
}

Assert-PlanCase -Name "item subtype foreign to mode" -ExpectCode "PLN-104" -Mutate {
    param($p)
    $p.workstreams[1].items[0].subtype = "TASK"
}

Assert-PlanCase -Name "metric key borrowed from another mode" -ExpectCode "PLN-105" -Mutate {
    param($p)
    $p.workstreams[0].items[0].metrics = [pscustomobject]@{ recordsTotal = 5 }
}

Assert-PlanCase -Name "duplicate code across workstreams" -ExpectCode "PLN-106" -Mutate {
    param($p)
    $p.workstreams[1].items[0].code = "T1"
}

Assert-PlanCase -Name "item referencing unknown containerCode" -ExpectCode "PLN-106" -Mutate {
    param($p)
    $p.workstreams[0].items[0].containerCode = "S99"
}

Assert-PlanCase -Name "schemaVersion 1.2 without executionContractId" -ExpectCode "PLN-107" -Mutate {
    param($p)
    $p.workstreams[0].executionContractId = ""
}

Assert-PlanCase -Name "schemaVersion 1.2 without trace" -ExpectCode "PLN-107" -Mutate {
    param($p)
    $p.trace.idempotencyKey = ""
}

Assert-PlanCase -Name "dependency with unknown type" -ExpectCode "PLN-108" -Mutate {
    param($p)
    $p.dependencies[0].type = "SOMEDAY_AFTER"
}

Assert-PlanCase -Name "dependency ref not resolving to any code" -ExpectCode "PLN-108" -Mutate {
    param($p)
    $p.dependencies[1].targetRef = "MS-GHOST"
}

Write-Host ""
Write-Host "=== validate-plan tests: $script:passed passed, $script:failed failed ==="
if ($script:failed -gt 0) { exit 1 } else { exit 0 }
