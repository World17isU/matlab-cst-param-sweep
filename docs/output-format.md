# Output format

## Folder layout

```text
results/run-001/
├── K_sample_001_absorption.txt
├── K_sample_002_absorption.txt
├── F_sample_001_absorption.txt
├── F_sample_002_absorption.txt
├── summary.csv
├── results.mat
└── sweep.log
```

File names follow `<prefix>_sample_<NNN>_absorption.txt`, where `<prefix>` comes
from `cfg.States(k).prefix` and `<NNN>` is the 1-based CSV row index, zero
padded to three digits.

## Absorption file

Two tab-separated columns, no header, scientific notation:

```text
1.0000000000e+00	9.8765432100e-01
1.0100000000e+00	9.8765432100e-01
```

| Column | Meaning |
| --- | --- |
| 1 | Frequency in the unit reported by the CST export header (`unit` in `readSParameters`) |
| 2 | Absorptance `A = 1 - |S11|^2`, clipped to `[0, 1]` |

Files are written with `%.10e`, so they are lossless enough for plotting and
for resuming with `SkipExistingResults`.

## Summary CSV

`summary.csv` contains one row per attempted sample, in execution order.

| Column | Type | Meaning |
| --- | --- | --- |
| `state` | string | State label |
| `sample` | double | 1-based row index in the parameter table |
| `<parameter>` | double | One column per `ParameterNames` entry |
| `valid` | logical | `true` when the sample was solved (or successfully reused) |
| `reason` | string | Empty when valid; skip or failure reason otherwise |
| `peak_absorptance` | double | Maximum absorptance |
| `peak_frequency` | double | Frequency of the maximum |
| `frequency_unit` | string | Unit reported by the export header (`THz`, `GHz`, ...), empty when reused from disk |
| `mean_absorptance` | double | Mean over the exported band |
| `output_file` | string | Path to the absorption file |
| `elapsed_seconds` | double | Wall-clock time for the sample |

Rows skipped by a constraint keep `valid = false` and a reason such as
`R2<=R3`; failed solves record the phase (`setup failed: ...`,
`export failed: ...`, `solver timeout`).

## results.mat

Written when `SaveMatFile` is true. The MAT file contains the variables:

| Variable | Contents |
| --- | --- |
| `generatedAt` | `datetime` of the run |
| `packageVersion` | `cstsweep.version()` |
| `config` | The `cstsweep.Config` object used for the run |
| `snapshot` | Initial parameter values (`names`, `values`) captured before the first rebuild |
| `records` | Struct array with one element per sample, including `Frequency` and `Absorption` curves |
| `summary` | The summary table |

## Dry-run plan

`DryRun = true` writes `planned_samples.csv` with the same parameter columns
plus:

| Column | Meaning |
| --- | --- |
| `state` | State label |
| `state_value` | Value that would be written to the state parameter |
| `sample` | Row index |
| `eligible` | `false` when a constraint rejects the row |
| `reason` | Constraint reason for ineligible rows |

No CST connection is made and no absorption files are written in dry-run mode.

## Log file

One timestamped line per event:

```text
[2026-11-20 09:41:02] INFO  ======================================
[2026-11-20 09:41:02] INFO  Broadband state (S = 80000, prefix K)
[2026-11-20 09:41:02] INFO  ======================================
[2026-11-20 09:41:02] INFO  Sample 001 [Broadband]: R1=6, R2=4.6, ...
[2026-11-20 09:41:37] INFO  Peak absorptance 0.9876 at 1.2345 THz (35.1 s, GetSolverStatus)
```
