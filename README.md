# MATLAB-CST Parameter Sweep

![MATLAB](https://img.shields.io/badge/MATLAB-R2021a%2B-0076A8)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6)
![CST Studio Suite](https://img.shields.io/badge/CST%20Studio%20Suite-2020%2B-1F6FEB)
![License](https://img.shields.io/badge/license-MIT-green)

Reproducible, scripted parameter sweeps for [CST Studio Suite](https://www.3ds.com/products/simulia/cst-studio-suite)
projects, driven from MATLAB through the CST COM automation interface.

The repository turns a one-off automation script into a small, documented MATLAB
package: configuration lives in one place, the COM session is always cleaned up,
every sample is validated, logged, and written to disk, and the original model
parameters are restored even when a run fails.

---

## Overview

Given a CSV file of geometry parameter sets and a CST project with a parametric
3D model, the runner:

1. snapshots every parameter of the open CST model (including the state
   parameter) so it can be restored afterwards;
2. for each **state** (for example a broadband and a narrowband configuration),
   sets the state parameter and rebuilds the model;
3. for each **sample**, optionally checks geometry constraints, writes the
   parameters, rebuilds, starts the solver, waits for completion, exports the
   reflection coefficient, and computes the absorptance
   `A(f) = 1 - |S11(f)|^2`;
4. writes one text file per sample, a `summary.csv`, and an archival
   `results.mat`;
5. restores the original parameter values and releases the COM objects.

The whole sweep is driven by a configuration object, so a run can be reproduced
from a single `.m` file.

## Features

- **Declarative configuration** — no hard-coded paths, solver names, or sample
  counts in the execution code.
- **Multiple model states** — sweep the same parameter table under different
  values of a state parameter (the original use case: `S = 80000` and
  `S = 150`), each with its own file prefix.
- **Geometry constraints** — invalid parameter combinations (for example
  `R2 <= R3`) are skipped and recorded instead of reaching the solver.
- **Dry-run planning** — validate the CSV, constraints, and file plan without
  connecting to CST.
- **Resumable runs** — reuse existing absorption files with
  `SkipExistingResults` after an interrupted sweep.
- **Guaranteed cleanup** — a `Session` destructor restores the parameter
  snapshot and releases COM handles on success, error, and `Ctrl+C`.
- **Solver watchdog** — probes several CST solver status methods and falls back
  to polling the result tree when none is available, so a run cannot silently
  assume the solver finished.
- **Format detection** — S-parameter exports are recognised as dB or linear
  magnitude, with an explicit override when the automatic heuristic is
  ambiguous.
- **Structured output** — per-sample absorption files, a machine-readable
  `summary.csv`, and a `results.mat` archive containing the raw curves.
- **Unit tests** — the parsing, validation, and dry-run logic is covered by
  `matlab.unittest` tests that do not require CST.

## Requirements

| Component | Requirement |
| --- | --- |
| Operating system | Windows (COM automation is Windows-only) |
| MATLAB | R2021a or later |
| CST Studio Suite | 2020 or later, with a valid licence and the COM interface available |
| CST project | A 3D project with the parameters named in `ParameterNames`, and a parameter for the state value |

## Installation

```bash
git clone https://github.com/<your-username>/matlab-cst-param-sweep.git
cd matlab-cst-param-sweep
```

In MATLAB:

```matlab
cd('path/to/matlab-cst-param-sweep')
startup          % adds src/ to the MATLAB path
```

`startup.m` only adds the package folder to the path; it does not modify any
global MATLAB settings.

## Quick start

1. Copy the example configuration and rename its function to `local_config`:

   ```matlab
   copyfile('config/local_config_example.m', 'config/local_config.m')
   ```

2. Point it at your CSV file, CST project, and output folder:

   ```matlab
   function cfg = local_config()
       cfg = cstsweep.Config();
       cfg.CsvPath = "data/parameters.csv";
       cfg.OutputDir = "results/run-001";
       cfg.TestMode = true;        % run only a few samples first
       cfg.TestSampleCount = 2;
       cfg.States(1).value = 80000;
       cfg.States(2).value = 150;
   end
   ```

3. Open the CST project in the CST Studio Suite GUI.

4. Run the sweep:

   ```matlab
   summary = run_sweep("config/local_config.m");
   ```

   or drive the object directly:

   ```matlab
   cfg = cstsweep.Config();
   cfg.CsvPath = "data/parameters.csv";
   cfg.OutputDir = "results/run-001";
   cfg.DryRun = true;              % plan only, no CST connection
   summary = cstsweep.SweepRunner(cfg).run();
   ```

## Agent skill

`skills/cst-param-sweep/` packages the workflow for AI coding agents:

- `SKILL.md` — when to use the toolkit, the dry-run-first workflow, success
  criteria, and safety rules;
- `references/configuration.md` and `references/troubleshooting.md` — condensed
  operational references;
- `scripts/check_prerequisites.ps1` — checks the repository, MATLAB, CST
  processes, and write access without starting either application;
- `scripts/smoke_test.m` — dry-runs the bundled example table; no CST needed;
- `scripts/run_sweep_batch.m` — runs a configuration under `matlab -batch` and
  prints a compact report.

```powershell
matlab -batch "addpath('skills/cst-param-sweep/scripts'); smoke_test(pwd)"
```

The skill assumes the repository is the working directory. It never approves a
full sweep without a preceding dry run and a short test run.

## How it works

```mermaid
flowchart LR
    A[Load CSV] --> B[Connect to CST]
    B --> C[Snapshot parameters]
    C --> D{For each state}
    D --> E[Set state parameter + rebuild]
    E --> F{For each sample}
    F --> G[Check constraints]
    G --> H[Write parameters + rebuild]
    H --> I[Reset results + start solver]
    I --> J[Wait for solver]
    J --> K[Export and parse S11]
    K --> L[A = 1 - |S11|^2]
    L --> M[Write sample file + record]
    M --> F
    F --> N[Next state]
    N --> D
    D --> O[Restore parameters + release COM]
    O --> P[summary.csv + results.mat]
```

Each sample is isolated: a failed rebuild, solver timeout, or export error is
recorded with a reason and the sweep continues (`ContinueOnError = true`), so a
long run is not lost because of one bad parameter set.

## Configuration

`cstsweep.Config` is the single source of truth. The most important options:

| Option | Default | Meaning |
| --- | --- | --- |
| `CsvPath` | `""` | CSV file with one row per parameter set (required) |
| `OutputDir` | `"results"` | Folder for sample files, log, summary, and archive |
| `ParameterNames` | `["R1","R2","R3","R6","R5","T5"]` | CST parameter names, in CSV column order |
| `StateParameterName` | `"S"` | CST parameter that selects the model state |
| `StateParameterPath` | `1D Results\S-Parameters\SZmax(1),Zmax(1)` | CST result tree path of the exported S-parameter |
| `States` | broadband / narrowband | State label, value, and output-file prefix |
| `SamplesPerState` | `200` | Number of CSV rows to run per state |
| `TestMode` | `false` | Limit each state to `TestSampleCount` rows |
| `DryRun` | `false` | Validate and plan without connecting to CST |
| `SkipExistingResults` | `false` | Reuse an existing absorption file instead of re-solving |
| `SolverObject` | `"auto"` | CST solver object name, or `auto` to try `FDSolver` then `Solver` |
| `SolverTimeoutSeconds` | `600` | Per-sample solver timeout |
| `SParameterFormat` | `"auto"` | `auto`, `db`, or `linear` |
| `Constraints` | `R2>R3`, `R5>R6` | Geometry rules evaluated before each solve |

The full list, including logging and lifecycle options, is documented in
[docs/configuration.md](docs/configuration.md).

## Input CSV format

The CSV must contain one column per entry in `ParameterNames` (extra columns are
ignored). Each row is one simulation.

```csv
R1,R2,R3,R6,R5,T5
6.00,4.60,3.40,1.20,2.80,0.30
6.20,4.65,3.45,1.25,2.85,0.31
6.40,4.70,3.50,1.30,2.90,0.32
```

Rules:

- Column names are matched case-sensitively against `ParameterNames`.
- Values must be numeric and finite; a non-numeric cell aborts the run with the
  offending table rows listed.
- Rows violating a constraint are skipped, not removed, so the output keeps a
  record of every planned sample.

## Output

For each valid sample the runner writes:

```text
results/run-001/
├── K_sample_001_absorption.txt     # two columns: frequency, absorptance
├── F_sample_001_absorption.txt
├── summary.csv                     # one row per attempted sample
├── results.mat                     # configuration + raw curves
└── sweep.log                       # timestamped log
```

`summary.csv` columns: state label, sample index, every geometry parameter,
validity flag, skip reason, peak absorptance, peak frequency, frequency unit,
mean absorptance, output file, and elapsed time.

The format is documented in [docs/output-format.md](docs/output-format.md).

## Assumptions and limitations

- **Absorptance model.** `A = 1 - |S11|^2` assumes a metal-backed absorber with
  negligible transmission. For a transmitting structure, extend
  `cstsweep.computeAbsorption` to include `|S21|^2`.
- **One solver at a time.** CST COM automation drives a single running
  application, so samples are solved sequentially. Parallel sweeps would need
  multiple CST instances and are out of scope.
- **Magnitude export.** The parser expects the ASCII export to contain
  frequency and S-parameter magnitude (dB or linear). Complex `real/imag`
  exports are not interpreted automatically.
- **Format heuristic.** Values in `[0, 1]` are read as linear magnitude;
  anything else is read as dB. Set `SParameterFormat` explicitly when the data
  could be either.
- **Result-tree fallback.** When CST exposes no solver status method, the
  runner infers completion from the presence of the S-parameter tree item; this
  is documented in [docs/architecture.md](docs/architecture.md).

## Repository layout

```text
matlab-cst-param-sweep/
├── run_sweep.m                 # entry point
├── startup.m                   # adds src/ to the MATLAB path
├── config/
│   ├── default_config.m        # dry-run demo configuration
│   └── local_config_example.m  # copy to local_config.m (git-ignored)
├── src/+cstsweep/
│   ├── Config.m                # validated configuration object
│   ├── Session.m               # CST COM session and parameter snapshot
│   ├── SweepRunner.m           # orchestration
│   ├── Logger.m                # console + file logging
│   ├── loadParameterTable.m    # CSV loading and validation
│   ├── evaluateConstraints.m   # geometry rules
│   ├── readSParameters.m       # CST ASCII export parser
│   ├── detectSParameterFormat.m
│   ├── detectFrequencyUnit.m
│   ├── computeAbsorption.m
│   ├── readAbsorptionFile.m
│   ├── writeAbsorptionFile.m
│   ├── loadConfig.m
│   └── version.m
├── examples/
│   ├── parameters_example.csv
│   └── run_example.m
├── skills/cst-param-sweep/      # agent skill: SKILL.md, references, scripts
├── tests/                      # matlab.unittest suite (no CST required)
└── docs/
```

## Development

Run the unit tests (no CST installation needed):

```matlab
addpath('tests')
results = run_tests();
```

Static analysis with [miss_hit](https://github.com/florianschanda/miss_hit):

```bash
python -m pip install miss_hit
mh_lint src tests config examples skills/cst-param-sweep/scripts run_sweep.m startup.m
```

CI runs the same linter on every push and pull request.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `CST Studio Suite is not running` | CST is closed or no project is open | Open the project, or set `StartCstIfNeeded` and `ProjectPath` |
| `Parameter "..." did not evaluate to a finite scalar` | Name mismatch between CSV and CST | Check `ParameterNames` against the CST parameter list |
| `No solver status method responded` | CST version exposes a different API | The run falls back to result-tree polling; check `SolverObject` |
| `Solver timeout` | Slow mesh or insufficient timeout | Raise `SolverTimeoutSeconds`; inspect `sweep.log` |
| `S-parameter file not found` | Wrong `StateParameterPath` | Select the result in CST and copy its tree path |
| Absorption looks inverted | dB/linear misdetection | Set `SParameterFormat` to `"db"` or `"linear"` |
| `Missing parameter column(s)` | CSV header mismatch | Match the CSV header to `ParameterNames` exactly |

## Publishing to GitHub

The repository is ready to push. Create an empty repository on GitHub, then:

```bash
git remote add origin https://github.com/<your-username>/matlab-cst-param-sweep.git
git branch -M main
git push -u origin main
```

With the GitHub CLI:

```bash
gh repo create matlab-cst-param-sweep --public --source=. --remote=origin --push
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before
opening a pull request, and follow the
[Contributor Covenant](CODE_OF_CONDUCT.md).

## License

Released under the [MIT License](LICENSE).

## Acknowledgements

The initial version of this workflow was developed for absorptance sweeps of
parametric CST unit-cell models. The package structure follows common MATLAB
toolbox conventions so that the simulation logic can be reviewed and extended
independently of any single project file.
