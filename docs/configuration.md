# Configuration reference

All sweep behaviour is controlled by a `cstsweep.Config` object. Every option
can be set as a property or passed to the constructor as a name-value pair:

```matlab
cfg = cstsweep.Config('CsvPath', "data/params.csv", 'Verbose', false);
cfg.SamplesPerState = 50;
```

`cstsweep.Config.validate` is called by `cstsweep.SweepRunner` and reports all
problems it finds at once under the `cstsweep:Config:Invalid` identifier.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `CsvPath` | string | `""` | CSV file with one column per parameter and one row per sample. Required. |
| `OutputDir` | string | `"results"` | Folder for sample files, log, summary, and archive. Created when missing. |
| `ParameterNames` | string row | `["R1","R2","R3","R6","R5","T5"]` | CST parameter names, in CSV column order. Must be valid identifiers and unique. |
| `StateParameterName` | string | `"S"` | CST parameter that selects the model state. Must not appear in `ParameterNames`. |
| `StateParameterPath` | string | `1D Results\S-Parameters\SZmax(1),Zmax(1)` | Result tree path of the S-parameter to export. |
| `States` | struct array | broadband / narrowband | State definitions; see below. |
| `SamplesPerState` | positive integer | `200` | Number of CSV rows solved per state; clamped to the table size. |
| `TestMode` | logical | `false` | Run only `TestSampleCount` rows per state. |
| `TestSampleCount` | positive integer | `1` | Rows per state in test mode. |
| `DryRun` | logical | `false` | Validate the table and write a plan without connecting to CST. |
| `SkipExistingResults` | logical | `false` | Reuse an existing absorption file instead of re-solving that sample. |
| `ResetResultsBeforeRun` | logical | `true` | Call `ResetResults` before each solver run so exports cannot be stale. |
| `SolverObject` | string | `"auto"` | CST solver object (`FDSolver`, `Solver`, ...) or `auto` to try `FDSolver` then `Solver`. |
| `SolverTimeoutSeconds` | positive double | `600` | Maximum wait per sample. |
| `PollIntervalSeconds` | positive double | `5` | Delay between solver status checks. |
| `RebuildSettleSeconds` | non-negative double | `2` | Pause after `Rebuild` before writing results. |
| `SParameterFormat` | string | `"auto"` | `auto`, `db`, or `linear`. |
| `Constraints` | struct array | `R2>R3`, `R5>R6` | Rules checked before each solve; see below. |
| `KeepTemporaryFiles` | logical | `false` | Keep the raw ASCII export next to the results. |
| `SaveMatFile` | logical | `true` | Write `results.mat` with configuration and raw curves. |
| `ContinueOnError` | logical | `true` | Record a failed sample and continue instead of aborting. |
| `LogFile` | string | `""` | Log destination; empty means `<OutputDir>/sweep.log`. |
| `Verbose` | logical | `true` | Mirror log lines to the MATLAB command window. |
| `StartCstIfNeeded` | logical | `false` | Launch CST when no running instance is found. |
| `ProjectPath` | string | `""` | Project opened when `StartCstIfNeeded` is true. Required in that case. |

## States

`States` is a struct array. Every element needs three fields:

```matlab
cfg.States = struct( ...
    "label",  {"Broadband", "Narrowband"}, ...
    "value",  {80000, 150}, ...
    "prefix", {"K", "F"});
```

| Field | Meaning |
| --- | --- |
| `label` | Human-readable name used in the log and in `summary.csv`. |
| `value` | Value written to `StateParameterName` before the state's samples. |
| `prefix` | Prefix for that state's output files (`K_sample_001_...`). |

Labels and prefixes must be unique; prefixes must be valid file name
components.

## Constraints

`Constraints` is a struct array with a comparison per element:

```matlab
cfg.Constraints = struct( ...
    "first",    {"R2", "R5"}, ...
    "second",   {"R3", "R6"}, ...
    "relation", {"gt", "gt"}, ...
    "reason",   {"R2<=R3", "R5<=R6"});
```

`relation` is one of `gt` (`>`), `ge` (`>=`), `lt` (`<`), or `le` (`<=`).
`first` and `second` must be listed in `ParameterNames`. When a rule fails, the
sample is recorded with `valid = false` and `reason` set to the rule's
`reason` text, and no solve is started.

Set `cfg.Constraints = struct([])` to disable constraint checks.

## Typical configurations

### Short validation run

```matlab
cfg.TestMode = true;
cfg.TestSampleCount = 2;
cfg.SamplesPerState = 200;   % ignored in test mode
```

### Plan only

```matlab
cfg.DryRun = true;           % no CST connection, writes planned_samples.csv
```

### Resume an interrupted sweep

```matlab
cfg.SkipExistingResults = true;
```

Samples whose absorption file already exists are read back, summarised, and
not re-solved. Delete the incomplete files (or change `OutputDir`) to force a
new solve.

### Explicit format

```matlab
cfg.SParameterFormat = "db";  % or "linear"
```

Use this when the automatic heuristic is ambiguous, for example when dB values
happen to lie between `-1` and `0`.

## Validation rules

`validate` reports every problem it finds, including:

- missing or non-existent `CsvPath`;
- empty, duplicate, or non-identifier `ParameterNames`;
- `StateParameterName` also listed in `ParameterNames`;
- empty `StateParameterName` or `StateParameterPath`;
- missing or non-finite `States.value`, duplicate labels or prefixes, or an
  invalid prefix;
- constraints that reference unknown parameters or an unknown relation;
- `StartCstIfNeeded` without `ProjectPath`.

## Logging

`LogFile` defaults to `<OutputDir>/sweep.log`. The logger writes one line per
event:

```text
[2026-11-20 09:41:02] INFO  Sample 001 [Broadband]: R1=6, R2=4.6, ...
```

Warnings and errors are always printed to the command window, even when
`Verbose` is false.
