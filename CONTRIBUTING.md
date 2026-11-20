# Contributing

Thanks for considering a contribution. This project automates CST Studio Suite
from MATLAB, so changes usually fall into one of three groups: MATLAB logic,
CST interaction, or documentation.

## Ways to contribute

- Report a bug with a minimal configuration and the relevant log excerpt.
- Improve the documentation or add a worked example.
- Add tests for parsing and validation logic (these do not need CST).
- Extend the runner, for example with transmission support or a different
  result type.

## Development setup

1. Clone the repository and open MATLAB in the repository root.
2. Run `startup` once to add `src/` to the path.
3. Verify the baseline:

   ```matlab
   results = run_tests();
   assert(all([results.Passed]))
   ```

4. Optional static analysis:

   ```bash
   python -m pip install miss_hit
   mh_lint src tests config examples skills/cst-param-sweep/scripts run_sweep.m startup.m
   ```

A licence for CST Studio Suite is only required for integration testing; unit
tests must not depend on CST.

## Style

- Follow the [MATLAB Style Guidelines 2.0](https://www.mathworks.com/matlabcentral/fileexchange/46056-matlab-style-guidelines-2-0)
  where practical.
- Four spaces, no tabs, LF line endings, UTF-8.
- Classes use `UpperCamelCase`, functions and variables `lowerCamelCase`.
- Package functions live in `src/+cstsweep/` and start with a one-line H1
  comment followed by a short description.
- Keep lines at or below 90 characters where possible.
- Prefer explicit `arguments` blocks for public functions.
- Never hard-code absolute paths in committed files.

## Tests

- Add or update a test in `tests/` for every behaviour change.
- Each test must be independent and must clean up temporary files through
  `matlab.unittest.fixtures.TemporaryFolderFixture`.
- Error identifiers are part of the API: assert on them (for example
  `cstsweep:SParams:NoData`) rather than on message text.

## Pull requests

1. Fork the repository and create a topic branch.
2. Keep commits focused; use the imperative mood in the subject line
   (`Add resume support for interrupted sweeps`).
3. Describe the motivation, the change, and how it was verified.
4. Confirm that `run_tests` passes and that the linter reports no errors.
5. Update `README.md`, `docs/`, and `CHANGELOG.md` when behaviour changes.

## Reporting bugs

Include:

- MATLAB release (`version`) and CST Studio Suite release.
- The configuration relevant to the failure, with local paths redacted.
- The matching lines from `sweep.log`.
- Whether the project is time domain or frequency domain.

Please remove proprietary model data and license information before posting.

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
