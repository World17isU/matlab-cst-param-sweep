# Configuration reference

`cstsweep.Config` is the single source of truth. Set properties directly or pass
name-value pairs:

```matlab
cfg = cstsweep.Config('CsvPath', "data/params.csv", 'Verbose', false);
```

`cstsweep.SweepRunner` calls `cfg.validate()` and reports all problems at once
under `cstsweep:Config:Invalid`.

## Options

| Option | Type | Default | Purpose |
| --- | --- | --- | --- |
| `CsvPath` | string | `""` | Parameter table; required |
| `OutputDir` | string | `"results"` | Artifacts folder; created if missing |
| `ParameterNames` | string row | `["R1","R2","R3","R6","R5","T5"]` | CST names in CSV column order |
| `StateParameterName` | string | `"S"` | CST parameter selecting the state |
| `StateParameterPath` | string | `1D Results\S-Parameters\SZmax(1),Zmax(1)` | Result tree path to export |
| `States` | struct array | broadband / narrowband | Label, value, and file prefix |
| `SamplesPerState` | integer | `200` | Rows per state, clamped to CSV size |
| `TestMode` | logical | `false` | Limit each state to `TestSampleCount` rows |
| `TestSampleCount` | integer | `1` | Rows per state in test mode |
| `DryRun` | logical | `false` | Plan only; no CST connection |
| `SkipExistingResults` | logical | `false` | Reuse absorption files instead of solving |
| `ResetResultsBeforeRun` | logical | `true` | Clear CST results before each solve |
| `SolverObject` | string | `"auto"` | Solver object name; `auto` tries `FDSolver`, then `Solver` |
| `SolverTimeoutSeconds` | double | `600` | Per-sample watchdog |
| `PollIntervalSeconds` | double | `5` | Status poll period |
| `RebuildSettleSeconds` | double | `2` | Pause after `Rebuild` |
| `SParameterFormat` | string | `"auto"` | `auto`, `db`, or `linear` |
| `Constraints` | struct array | `R2>R3`, `R5>R6` | Rules checked before solving |
| `KeepTemporaryFiles` | logical | `false` | Keep the raw ASCII export |
| `SaveMatFile` | logical | `true` | Write `results.mat` |
| `ContinueOnError` | logical | `true` | Continue after a failed sample |
| `LogFile` | string | `""` | Defaults to `<OutputDir>/sweep.log` |
| `Verbose` | logical | `true` | Mirror log lines to the command window |
| `StartCstIfNeeded` | logical | `false` | Launch CST when no instance is running |
| `ProjectPath` | string | `""` | Project opened when launching CST |

## States

```matlab
cfg.States = struct( ...
    "label",  {"Broadband", "Narrowband"}, ...
    "value",  {80000, 150}, ...
    "prefix", {"K", "F"});
```

- `label` — used in the log and `summary.csv`.
- `value` — written to `StateParameterName` before the state's samples.
- `prefix` — file prefix: `<prefix>_sample_001_absorption.txt`.

Labels and prefixes must be unique; prefixes must be valid file-name components.

## Constraints

```matlab
cfg.Constraints = struct( ...
    "first",    {"R2", "R5"}, ...
    "second",   {"R3", "R6"}, ...
    "relation", {"gt", "gt"}, ...
    "reason",   {"R2<=R3", "R5<=R6"});
```

`relation` is `gt`, `ge`, `lt`, or `le`. Both parameters must appear in
`ParameterNames`. A failed rule marks the sample invalid with that `reason` and
skips the solve. Disable with `cfg.Constraints = struct([])`.

## Recipes

Short validation:

```matlab
cfg.TestMode = true;
cfg.TestSampleCount = 2;
```

Plan only:

```matlab
cfg.DryRun = true;
```

Resume:

```matlab
cfg.SkipExistingResults = true;
```

Explicit format (when dB values fall between -1 and 0):

```matlab
cfg.SParameterFormat = "db";
```

## Validation rules

`validate` reports:

- missing or non-existent `CsvPath`;
- empty, duplicate, or non-identifier `ParameterNames`;
- `StateParameterName` also listed in `ParameterNames`;
- empty `StateParameterName` or `StateParameterPath`;
- non-finite or non-scalar `States.value`, duplicate labels/prefixes, invalid
  prefix characters;
- constraints referencing unknown parameters or an unknown relation;
- `StartCstIfNeeded` without `ProjectPath`.

## CSV format

```csv
R1,R2,R3,R6,R5,T5
6.00,4.60,3.40,1.20,2.80,0.30
6.20,4.65,3.45,1.25,2.85,0.31
```

Extra columns are ignored. Non-numeric cells abort the run with the offending
table rows listed. Column names are case-sensitive.
