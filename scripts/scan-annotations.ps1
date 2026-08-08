<#
.SYNOPSIS
    RWANG Annotation Scanner — scans source files for @req, @spec, @designs, @tested annotations
    and plain requirement ID references (FR-xxx, NFR-xxx, SDD-xxx, etc.)

.DESCRIPTION
    Produces a JSON report of all doc-code links found in the project.
    Used by rwang:doc-graph to build the document graph.

.PARAMETER Path
    Root directory to scan (default: current directory)

.PARAMETER Format
    Output format: "json" or "table" (default: json)

.PARAMETER IncludeUnstructured
    Also scan for plain requirement references like "# FR-001" (default: true)

.EXAMPLE
    .\scan-annotations.ps1 -Path "D:\GPIC" -Format table
#>

param(
    [string]$Path = ".",
    [string]$Format = "json",
    [bool]$IncludeUnstructured = $true
)

$ErrorActionPreference = "Stop"

# File extensions to scan
$Extensions = @("*.ts", "*.tsx", "*.js", "*.jsx", "*.py", "*.go", "*.java", "*.rs", "*.cs")

# Directories to skip
$SkipDirs = @("node_modules", "__pycache__", ".venv", "venv", ".git", "dist", "build", ".next", "coverage")

# Annotation patterns
$AnnotationPatterns = @{
    "req"     = '@req\s+([\w\-,\s]+)'
    "spec"    = '@spec\s+([\w\-,\s]+)'
    "designs" = '@designs\s+(.+?)(?:\s*$|\s*—)'
    "tested"  = '@tested\s+(.+?)(?:\s*$|\s*—)'
}

# Unstructured requirement ID pattern
$ReqIdPattern = '(FR|NFR|SDD|SEC|AI-AGT|AI-ETH|BR|AC|DR|IR)-(\d{3})'

function Get-SourceFiles {
    param([string]$RootPath)

    $files = @()
    foreach ($ext in $Extensions) {
        $found = Get-ChildItem -Path $RootPath -Filter $ext -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $skip = $false
                foreach ($dir in $SkipDirs) {
                    if ($_.FullName -match [regex]::Escape($dir)) {
                        $skip = $true
                        break
                    }
                }
                -not $skip
            }
        $files += $found
    }
    return $files
}

function Scan-File {
    param(
        [System.IO.FileInfo]$File,
        [string]$RootPath
    )

    $relativePath = $File.FullName.Substring($RootPath.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'
    $lines = Get-Content $File.FullName -ErrorAction SilentlyContinue

    $annotations = @()
    $lineNum = 0

    foreach ($line in $lines) {
        $lineNum++

        # Check structured annotations
        foreach ($key in $AnnotationPatterns.Keys) {
            if ($line -match $AnnotationPatterns[$key]) {
                $value = $Matches[1].Trim()
                $ids = ($value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

                $annotations += @{
                    file       = $relativePath
                    line       = $lineNum
                    type       = "structured"
                    annotation = "@$key"
                    ids        = $ids
                    raw        = $line.Trim()
                }
            }
        }

        # Check unstructured requirement references
        if ($IncludeUnstructured) {
            $reqMatches = [regex]::Matches($line, $ReqIdPattern)
            if ($reqMatches.Count -gt 0) {
                # Skip if this line already has a structured annotation
                $hasStructured = $false
                foreach ($key in $AnnotationPatterns.Keys) {
                    if ($line -match ('@' + $key)) {
                        $hasStructured = $true
                        break
                    }
                }

                if (-not $hasStructured) {
                    $ids = $reqMatches | ForEach-Object { $_.Value }
                    $annotations += @{
                        file       = $relativePath
                        line       = $lineNum
                        type       = "unstructured"
                        annotation = "comment"
                        ids        = @($ids)
                        raw        = $line.Trim()
                    }
                }
            }
        }
    }

    return $annotations
}

# Main execution
$resolvedPath = (Resolve-Path $Path).Path
$files = Get-SourceFiles -RootPath $resolvedPath

$allAnnotations = @()
$fileCount = 0

foreach ($file in $files) {
    $result = Scan-File -File $file -RootPath $resolvedPath
    if ($result.Count -gt 0) {
        $allAnnotations += $result
        $fileCount++
    }
}

# Build summary
$structured = ($allAnnotations | Where-Object { $_.type -eq "structured" }).Count
$unstructured = ($allAnnotations | Where-Object { $_.type -eq "unstructured" }).Count

$allIds = @()
foreach ($ann in $allAnnotations) {
    $allIds += $ann.ids
}
$uniqueIds = ($allIds | Sort-Object -Unique)

$report = @{
    generated_by = "rwang:scan-annotations"
    generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    root_path    = $resolvedPath
    summary      = @{
        files_scanned       = $files.Count
        files_with_refs     = $fileCount
        structured_count    = $structured
        unstructured_count  = $unstructured
        total_annotations   = $allAnnotations.Count
        unique_req_ids      = $uniqueIds.Count
        unique_ids          = $uniqueIds
    }
    annotations  = $allAnnotations
}

if ($Format -eq "json") {
    $report | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n=== RWANG Annotation Scan Report ===" -ForegroundColor Cyan
    Write-Host "Root: $resolvedPath"
    Write-Host "Files scanned: $($files.Count)"
    Write-Host "Files with references: $fileCount"
    Write-Host "Structured annotations (@req, @spec, etc.): $structured"
    Write-Host "Unstructured references (# FR-xxx): $unstructured"
    Write-Host "Unique requirement IDs: $($uniqueIds.Count)"
    Write-Host ""

    if ($allAnnotations.Count -gt 0) {
        Write-Host "--- Annotations ---" -ForegroundColor Yellow
        foreach ($ann in $allAnnotations) {
            $marker = if ($ann.type -eq "structured") { "[S]" } else { "[U]" }
            $idStr = $ann.ids -join ", "
            Write-Host "$marker $($ann.file):$($ann.line) — $idStr"
        }
    } else {
        Write-Host "No annotations found." -ForegroundColor Red
    }
}
