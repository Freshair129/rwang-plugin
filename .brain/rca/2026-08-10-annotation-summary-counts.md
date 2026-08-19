# RCA: annotation summary counts

## Symptom

`scan-annotations.ps1` reported six structured and six unstructured annotations while its JSON
payload contained two annotation objects.

## Evidence

Running the scanner on this repository produced `total_annotations: 2`, while
`structured_count: 6` and `unstructured_count: 6`. The two objects were one structured annotation
and one unstructured requirement reference.

## Root Cause

When a PowerShell pipeline returns one hashtable, calling `.Count` directly reads the number of
keys in that hashtable rather than the number of matching annotation objects. The summary counters
did not wrap the pipeline result in an array.

## Why the issue escaped detection

The scanner had parse-level coverage only. No check compared `total_annotations` with the sum of
the structured and unstructured summary counts for a single-result scan.

## Proposed prevention

Wrap filtered pipeline results in `@(...)` before reading `.Count`, and include the single-result
summary invariant in future scanner smoke coverage.
