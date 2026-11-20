---
name: cst-param-sweep
description: Run reproducible absorptance parameter sweeps for CST Studio Suite projects from MATLAB over COM. Use when asked to plan, run, resume, or validate a CST geometry sweep, or to interpret the toolkit's summary.csv, sweep.log, and absorption files.
---

# CST parameter sweep

This skill operates the MATLAB-CST toolkit in this repository. The toolkit
writes geometry parameters into an open CST 3D project, rebuilds and solves each
CSV row under each model state, exports `|S11|`, and records
`A(f) = 1 - |S11(f)|^2`.

## Use this skill when

- The user wants to plan, run, resume, or troubleshoot a CST parameter sweep.
- The user asks how to configure this toolkit's CSV, states, or constraints.
- The user needs absorptance curves or peak values from an existing run.

Do not use it to edit CST geometry, export CAD, or drive a project that has no
parametric model. The toolkit only changes parameter values; it never saves the
CST project.

## Preconditions

1. Windows with MATLAB R2021a or later available as `matlab`.
2. CST Studio Suite running, with the target 3D project open.
3. Repository at `E:\matlab-cst-param-sweep` (adjust paths when moved).
4. A CSV with one column per parameter and one row per sample.

Check readiness before touching the solver:

```powershell
powershell -NoProfile -File "E:\matlab-cst-param-sweep\skills\cst-param-sweep\scripts\check_prerequisites.ps1" -RepoRoot "E:\matlab-cst-param-sweep"
```

## Workflow

### 1. Configure

Copy `config/local_config_example.m` to `config/local_config.m`, rename the
function to `local_config`, and set at least:

- `CsvPath` — the parameter table;
- `OutputDir` — a new folder per run;
- `ProjectPath` / `StartCstIfNeeded` — only if CST should be launched
  automatically.

Never reuse an `OutputDir` for a different parameter table unless the user
intends to resume; files are keyed by state prefix and sample index.

### 2. Dry run (no CST)

```powershell
matlab -batch "addpath('E:/matlab-cst-param-sweep/skills/cst-param-sweep/scripts'); smoke_test('E:/matlab-cst-param-sweep')"
```

Expected output: `Smoke test passed: 4 planned samples, all eligible.`
The smoke test validates the CSV, constraints, table construction, and output
folder, and writes `results/smoke/planned_samples.csv`.

For a custom table, run the configured plan instead:

```matlab
cfg = cstsweep.Config();
cfg.CsvPath = "data/parameters.csv";
cfg.OutputDir = "results/plan";
cfg.DryRun = true;
summary = cstsweep.SweepRunner(cfg).run();
```

### 3. Short real run

Set `TestMode = true`, `TestSampleCount = 1` or `2`, `DryRun = false`, then:

```powershell
matlab -batch "addpath('E:/matlab-cst-param-sweep/skills/cst-param-sweep/scripts'); run_sweep_batch('E:/matlab-cst-param-sweep', 'config/local_config.m')"
```

Confirm in `results/<run>/summary.csv` that the rows are `valid` and that
`peak_absorptance` lies in `[0, 1]`. If not, stop and diagnose before scaling up.

### 4. Full run

Only after the user confirms the short run. A 200 x 2 sweep can take hours:
start it as a background job, then poll `results/<run>/sweep.log`; do not hold an
interactive shell. Keep CST open and do not edit or save the project while the
sweep is running.

### 5. Resume after interruption

Set `SkipExistingResults = true` and rerun the same configuration. Existing
absorption files are parsed and summarised instead of re-solved; the log marks
them `Reused existing result`.

### 6. Report

Summarise for the user:

- the run folder and number of valid/total samples;
- peak absorptance and peak frequency per state;
- every non-empty `reason` value, grouped by cause;
- any solver timeouts.

## Commands

| Task | Command |
| --- | --- |
| Readiness check | see above |
| Smoke test (no CST) | `smoke_test('E:/matlab-cst-param-sweep')` |
| Run a config | `run_sweep_batch('E:/matlab-cst-param-sweep', 'config/local_config.m')` |
| Unit tests | `addpath('tests'); run_tests` |
| Inspect a run | read `summary.csv` and the tail of `sweep.log` |

## Key configuration

| Option | Effect |
| --- | --- |
| `CsvPath`, `OutputDir` | input table and artifact folder |
| `ParameterNames` | CST parameter names, CSV column order |
| `StateParameterName`, `States` | state parameter and per-state value/prefix |
| `SamplesPerState` | rows solved per state, clamped to CSV size |
| `TestMode`, `TestSampleCount`, `DryRun` | short validation before a long run |
| `SolverObject` | `auto` tries `FDSolver` then `Solver` |
| `SolverTimeoutSeconds` | per-sample watchdog (default 600 s) |
| `SParameterFormat` | `auto`, `db`, or `linear` |
| `SkipExistingResults` | resume without re-solving |
| `ContinueOnError` | keep going after a failed sample (default true) |

Full reference: `docs/configuration.md` and
`skills/cst-param-sweep/references/configuration.md`.

## Success criteria

- `summary.csv` has one row per planned sample.
- Solved rows have `valid = true` and `0 <= peak_absorptance <= 1`.
- Each absorption file has two numeric columns (frequency, absorptance).
- `sweep.log` ends with `Finished: N valid sample(s) of M attempted.`
- `sweep.log` contains `Restored ... parameter(s) to their initial values.`
- `results.mat` exists when `SaveMatFile` is true.

## Failure handling

| `reason` / symptom | Meaning | Action |
| --- | --- | --- |
| `R2<=R3`, `R5<=R6` | constraint rejected the row | expected; fix the CSV or constraints |
| `setup failed: ...` | parameter write, rebuild, or solver start failed | check project, names, solver licence |
| `solver timeout` | watchdog expired | raise `SolverTimeoutSeconds`, inspect the CST solver log |
| `export failed: ...` | tree path or ASCII export problem | verify `StateParameterPath` by selecting the result in CST |
| `reused existing result` | resume path | expected; delete the file to force a solve |
| `No solver status method responded` | CST status API differs | fallback polling; set `SolverObject` explicitly if exports fail |
| `CST Studio Suite is not running` | no COM instance | open CST and the project, or enable `StartCstIfNeeded` |

Deeper causes: `skills/cst-param-sweep/references/troubleshooting.md`.

## Safety and limits

- One sweep per CST instance; never run two MATLAB sessions against one project.
- The toolkit changes parameters and restores the snapshot on normal exit,
  error, and `Ctrl+C`. A hard MATLAB crash can leave values changed; restore
  them manually from the values printed in the run log or `results.mat`.
- Outputs are written only under `OutputDir`; temporary ASCII exports are
  deleted after each sample unless `KeepTemporaryFiles` is true.
- `A = 1 - |S11|^2` assumes negligible transmission (metal-backed absorber).
  Do not present it as total absorptance for a transmitting structure.
- Long runs are not resumable mid-solve; only completed samples are reused.

## References

- `skills/cst-param-sweep/references/configuration.md`
- `skills/cst-param-sweep/references/troubleshooting.md`
- `docs/configuration.md`, `docs/output-format.md`, `docs/architecture.md`
- `README.md`
