function smoke_test(repoRoot)
%SMOKE_TEST Validate the toolkit end to end without connecting to CST.
%
%   smoke_test() runs the bundled example table in dry-run mode and checks the
%   plan, constraints, table construction, and file output. It requires only
%   MATLAB, not CST.
%
%   smoke_test("E:/matlab-cst-param-sweep") uses an explicit repository root.
%
%   See also run_sweep, cstsweep.SweepRunner.

if nargin < 1 || strlength(string(repoRoot)) == 0
    repoRoot = string(pwd);
else
    repoRoot = string(repoRoot);
end

assert(isfile(fullfile(repoRoot, "run_sweep.m")), ...
    sprintf('Repository not found at %s.', repoRoot));

addpath(repoRoot);
addpath(fullfile(repoRoot, "src"));

cfg = cstsweep.Config();
cfg.CsvPath = fullfile(repoRoot, "examples", "parameters_example.csv");
cfg.OutputDir = fullfile(repoRoot, "results", "smoke");
cfg.SamplesPerState = 3;
cfg.TestMode = true;
cfg.TestSampleCount = 2;
cfg.DryRun = true;
cfg.Verbose = false;

summary = cstsweep.SweepRunner(cfg).run();

assert(height(summary) == 4, ...
    sprintf('Expected 4 planned samples, got %d.', height(summary)));
assert(all(summary.eligible), ...
    'Expected every example row to satisfy the default constraints.');
assert(isfile(fullfile(cfg.OutputDir, "planned_samples.csv")), ...
    'planned_samples.csv was not written.');

fprintf('Smoke test passed: %d planned samples, all eligible.\n', ...
    height(summary));
end
