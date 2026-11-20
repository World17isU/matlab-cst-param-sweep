# Troubleshooting

Diagnose in this order: connection, project/parameter names, solver, export,
parsing. The run log identifies the phase for every failed sample.

## Connection and project

**`CST Studio Suite is not running`** — `actxGetRunningServer` failed.

- Start CST Studio Suite and open the project, as the same Windows user and with
  the same bitness as MATLAB (64-bit).
- Or set `StartCstIfNeeded = true` and `ProjectPath` to the `.cst` file.
- Verify registration by running `actxGetRunningServer` in a fresh MATLAB
  session; a COM failure is not fixed by rerunning the sweep.

**`No CST 3D project is open`** — CST is running but `Active3D` returned an
empty object. Open the 3D project, or supply `ProjectPath`.

**`Could not evaluate parameter "..."`** — the name is not a double parameter in
the project, has different case, or belongs to a different project. Compare
`ParameterNames` with the CST parameter list.

**Parameters changed and not restored** — normal exits restore the snapshot; a
hard MATLAB crash or killed process may not. Restore manually. The snapshot is
also stored in `results.mat` once a run completes; otherwise take the values
from the CST history before the sweep.

## Solver

**`No solver status method responded`** — none of `GetSolverStatus`,
`IsRunning`, or `Status` returned a recognisable value. The runner falls back to
polling the result tree; the run continues. If exports still fail, set
`SolverObject` explicitly (`FDSolver` for time domain, `Solver` for frequency
domain).

**`solver timeout`** — the watchdog expired.

- Raise `SolverTimeoutSeconds` for large meshes.
- Check the CST solver log for meshing or licence problems.
- Confirm the solver actually started: CST shows a running solver in the status
  bar. A licence checkout failure aborts `Start`.

**`setup failed: ...`** — parameter write, rebuild, or solver start raised. The
message contains the CST error. Typical causes: invalid geometry from the row,
a rebuild dialog waiting for input, or the wrong solver object.

**Wrong solver ran** — `auto` tries `FDSolver` first. If the project is
frequency domain, set `cfg.SolverObject = "Solver"`.

## Export and parsing

**`export failed: ...`** — the result tree path is wrong or `ASCIIExport`
failed.

- Select the S-parameter result in CST and copy its tree path into
  `StateParameterPath` exactly (including the port indices).
- Confirm the solver produced that result: resetting results removes the tree
  item until the next solve.
- Export version 2010 is assumed.

**Absorptance flat at 0 or 1** — the export values were misread.

- Check the first data lines of the ASCII file: dB values are typically
  negative; linear magnitudes lie in `[0, 1]`.
- Set `SParameterFormat` explicitly.
- Confirm the exported quantity is `|S11|` magnitude, not real/imaginary parts.

**Absorptance above 1** — clipping hides a physical inconsistency. Verify the
structure is metal-backed and that the exported quantity is a magnitude.

## Constraints and resume

**`Skipped: R2<=R3` / `R5<=R6`** — expected; the row violates a geometry rule.
Fix the CSV or `Constraints`.

**`reused existing result`** — `SkipExistingResults` found a file. Delete it (or
change `OutputDir`) to force a solve.

## Output problems

**`summary.csv` missing** — the run aborted before `writeResults`. Check the
MATLAB error message; the sweep log may end at the failing sample.

**`results.mat` missing** — `SaveMatFile` is false, or the run aborted.

**Log file not created** — `OutputDir` was not writable, or `LogFile` points to
an invalid folder. Warnings are also printed to the command window.

## Environment checks

```powershell
powershell -NoProfile -File "E:\matlab-cst-param-sweep\skills\cst-param-sweep\scripts\check_prerequisites.ps1" -RepoRoot "E:\matlab-cst-param-sweep"
```

The script checks the repository layout, the MATLAB executable, CST processes,
write access to `results/`, and whether a local configuration exists. It does
not start MATLAB or CST.
