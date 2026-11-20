function cfg = local_config_example()
%LOCAL_CONFIG_EXAMPLE Template for a real sweep; copy to local_config.m.
%
%   config/local_config.m is listed in .gitignore so machine-specific paths
%   never reach the repository. Copy this file, rename the function to
%   local_config, adjust CsvPath, OutputDir, and ProjectPath, then run:
%
%       summary = run_sweep("config/local_config.m");
%
%   See also cstsweep.Config, run_sweep.

repoRoot = fileparts(fileparts(mfilename('fullpath')));

cfg = cstsweep.Config();

% Input and output locations.
cfg.CsvPath = string(fullfile(repoRoot, "data", "parameters.csv"));
cfg.OutputDir = string(fullfile(repoRoot, "results", "run-001"));

% CST project handling. Leave StartCstIfNeeded false when CST is already
% open; set it to true and fill in ProjectPath to launch CST automatically.
cfg.ProjectPath = "C:\path\to\your-project.cst";
cfg.StartCstIfNeeded = false;

% Sweep size. TestMode keeps a real run short while the setup is validated.
cfg.SamplesPerState = 200;
cfg.TestMode = true;
cfg.TestSampleCount = 2;

% Solver and export behaviour.
cfg.SolverObject = "auto";
cfg.SolverTimeoutSeconds = 600;
cfg.SParameterFormat = "auto";

% Turn off dry-run mode to solve.
cfg.DryRun = false;
cfg.Verbose = true;
end
