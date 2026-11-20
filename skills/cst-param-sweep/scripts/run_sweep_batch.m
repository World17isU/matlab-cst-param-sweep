function run_sweep_batch(repoRoot, configFile)
%RUN_SWEEP_BATCH Run one configured sweep and print a compact report.
%
%   run_sweep_batch() runs config/default_config.m from the current folder.
%
%   run_sweep_batch("E:/matlab-cst-param-sweep", "config/local_config.m") runs
%   a specific configuration from a specific repository root. Designed for
%   MATLAB -batch so a failed run returns a non-zero exit code.
%
%   See also run_sweep, cstsweep.SweepRunner.

if nargin < 1 || strlength(string(repoRoot)) == 0
    repoRoot = string(pwd);
else
    repoRoot = string(repoRoot);
end

if nargin < 2 || strlength(string(configFile)) == 0
    configFile = "config/default_config.m";
else
    configFile = string(configFile);
end

if ~isfile(fullfile(repoRoot, "run_sweep.m"))
    error('cst-param-sweep:batch:RepoNotFound', ...
        'run_sweep.m not found under %s.', repoRoot);
end

addpath(repoRoot);
oldFolder = pwd;
cleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(repoRoot);

summary = run_sweep(configFile);

if ~istable(summary)
    fprintf('Sweep finished.\n');
    return
end

names = string(summary.Properties.VariableNames);
if any(names == "eligible") && ~any(names == "valid")
    fprintf('\nDry run: %d planned sample(s), %d eligible.\n', ...
        height(summary), nnz(summary.eligible));
    return
end

valid = nnz(summary.valid);
fprintf('\nSweep finished: %d valid sample(s) of %d.\n', ...
    valid, height(summary));

validRows = summary(summary.valid, :);
if ~isempty(validRows)
    fprintf('Peak absorptance: %.4f .. %.4f\n', ...
        min(validRows.peak_absorptance), max(validRows.peak_absorptance));
end

failed = summary(~summary.valid, :);
if ~isempty(failed)
    fprintf('Invalid sample(s):\n');
    for k = 1:height(failed)
        fprintf('  %s sample %d: %s\n', ...
            failed.state(k), failed.sample(k), failed.reason(k));
    end
end
end
