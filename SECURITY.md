# Security policy

## Supported versions

Security fixes are applied to the latest release on the `main` branch.

| Version | Supported |
| --- | --- |
| 1.x | Yes |
| < 1.0 | No |

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private
vulnerability reporting (Security → Report a vulnerability) or contact the
maintainers through the address listed in the repository profile.

Include:

- a description of the issue and its impact;
- the affected version and MATLAB/CST versions;
- reproduction steps or a proof of concept;
- any suggested remediation.

You can expect an acknowledgement within a few working days and a coordinated
disclosure once a fix is available.

## Scope

This package drives a locally installed CST Studio Suite through COM. It does
not transmit model data or credentials, and it stores the configuration
(including any project path) in `results.mat`. Avoid committing generated
`results/` folders that contain confidential geometry.

## Handling generated data

- `results/` is ignored by `.gitignore` by default.
- Logs contain parameter values but no license information.
- Review `summary.csv` and `results.mat` before publishing a dataset.
