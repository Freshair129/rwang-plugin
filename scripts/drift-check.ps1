<#
.SYNOPSIS
    RWANG Drift Detector (PostToolUse hook)
    Checks if an edited file is tracked in doc-graph.json and warns about potential staleness.

.DESCRIPTION
    This script is called by the RWANG PostToolUse hook after Write/Edit operations.
    It reads the doc-graph.json and checks if the edited file has downstream
    documentation dependencies that may need updating.

    Environment variables set by Claude Code hooks:
    - TOOL_INPUT: JSON of the tool input (contains file_path)
    - TOOL_OUTPUT: JSON of the tool output
#>

$ErrorActionPreference = "SilentlyContinue"

# Find the project root (walk up looking for docs/.doc-graph.json)
function Find-DocGraph {
    $current = Get-Location
    while ($current) {
        $graphPath = Join-Path $current.Path "docs/.doc-graph.json"
        if (Test-Path $graphPath) {
            return $graphPath
        }
        $parent = Split-Path $current.Path -Parent
        if ($parent -eq $current.Path) { break }
        $current = Get-Item $parent
    }
    return $null
}

# Parse the edited file path from TOOL_INPUT
$toolInput = $env:TOOL_INPUT
if (-not $toolInput) { exit 0 }

try {
    $input = $toolInput | ConvertFrom-Json
    $editedFile = if ($input.file_path) { $input.file_path } else { $null }
} catch {
    exit 0
}

if (-not $editedFile) { exit 0 }

# Find doc-graph.json
$graphPath = Find-DocGraph
if (-not $graphPath) { exit 0 }

try {
    $graph = Get-Content $graphPath -Raw | ConvertFrom-Json
} catch {
    exit 0
}

# Normalize the edited file path for comparison
$projectRoot = Split-Path (Split-Path $graphPath -Parent) -Parent
$relativePath = $editedFile
if ($editedFile.StartsWith($projectRoot)) {
    $relativePath = $editedFile.Substring($projectRoot.Length).TrimStart('\', '/')
}
$relativePath = $relativePath -replace '\\', '/'

# Check if this file is a node in the graph
$matchingNode = $graph.nodes | Where-Object {
    $_.id -eq "code:$relativePath" -or $_.path -eq $relativePath
}

if (-not $matchingNode) { exit 0 }

# Find downstream edges (docs that describe this code)
$downstreamEdges = $graph.edges | Where-Object {
    ($_.from -eq $matchingNode.id -or $_.from -eq "code:$relativePath") -and
    ($_.type -eq "implements" -or $_.type -eq "designs" -or $_.type -eq "tests")
}

if ($downstreamEdges.Count -eq 0) { exit 0 }

# Find the document nodes that may need updating
$affectedDocs = @()
foreach ($edge in $downstreamEdges) {
    $targetNode = $graph.nodes | Where-Object { $_.id -eq $edge.to }
    if ($targetNode) {
        $affectedDocs += $targetNode
    }
}

if ($affectedDocs.Count -gt 0) {
    $docList = ($affectedDocs | ForEach-Object { $_.label ?? $_.id }) -join ", "
    Write-Host ""
    Write-Host "[RWANG] Drift warning: '$relativePath' is tracked in doc-graph." -ForegroundColor Yellow
    Write-Host "[RWANG] Potentially affected docs: $docList" -ForegroundColor Yellow
    Write-Host "[RWANG] Run /rwang:doc-preflight to check for staleness." -ForegroundColor DarkYellow
    Write-Host ""
}

exit 0
