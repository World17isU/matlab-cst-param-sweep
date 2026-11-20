# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-11-20

### Added

- Agent skill package under `skills/cst-param-sweep/`: `SKILL.md` operating
  instructions, configuration and troubleshooting references, a PowerShell
  readiness check, a no-CST smoke test, and a `matlab -batch` runner.
- The sweep log now reports the initial parameter values, how many parameters
  were restored, and `results.mat` stores the initial snapshot.

### Changed

- CI and contributor instructions lint the skill scripts as well.

## [1.0.0] - 2026-11-20

### Added

- `cstsweep.Config` with validated defaults, multi-state definitions, and
  geometry constraints.
- `cstsweep.Session` that owns the CST COM connection, snapshots and restores
  every parameter, starts the solver, waits with multiple status probes, and
  exports the S-parameter result.
- `cstsweep.SweepRunner` with per-sample error isolation, dry-run planning,
  resumable runs, and structured result collection.
- CSV parameter loading with numeric validation and clear error identifiers.
- S-parameter parser with dB/linear detection and frequency-unit reporting.
- Absorptance calculation and two-column output files.
- `summary.csv`, `results.mat`, and a timestamped `sweep.log`.
- `matlab.unittest` suite covering configuration, constraints, CSV parsing, and
  S-parameter parsing; the suite does not require CST.
- GitHub Actions workflow for MATLAB static analysis with `miss_hit`.

### Changed

- The original single-file script was split into a documented package with one
  configuration object; solver start, waiting, and export now live behind a
  session object instead of inside the sweep loop.
- Parameter restoration is guaranteed through a destructor instead of a final
  best-effort block.
- Constraint checks and CSV validation run before any solver call.
- Output file names, columns, and summary schema are documented rather than
  implicit.

### Fixed

- The previous wait loop could exit immediately when a CST status method was
  unavailable; the runner now detects that case and falls back to result-tree
  polling with a warning.
- Struct-array results no longer mix records with and without fields when a
  sample is skipped.
- The S-parameter export is parsed with explicit column positions, so a header
  cannot be paired with data.
