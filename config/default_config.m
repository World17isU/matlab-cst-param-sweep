function cfg = default_config()
%DEFAULT_CONFIG Configuration used by run_sweep() without arguments.
%
%   This default stays in dry-run mode and plans the bundled example table,
%   so a fresh clone can be exercised without a CST installation. Copy
%   local_config.example.m to local_config.m and edit the paths for a real
%   sweep.
%
%   See also cstsweep.Config, run_sweep.

repoRoot = fileparts(fileparts(mfilename('fullpath')));

cfg = cstsweep.Config();
cfg.CsvPath = string(fullfile(repoRoot, "examples", "parameters_example.csv"));
cfg.OutputDir = string(fullfile(repoRoot, "results", "demo"));
cfg.ParameterNames = ["R1", "R2", "R3", "R6", "R5", "T5"];
cfg.SamplesPerState = 5;
cfg.TestMode = true;
cfg.TestSampleCount = 2;
cfg.DryRun = true;
cfg.Verbose = true;
end
