function summary = run_example()
%RUN_EXAMPLE Plan the bundled parameter table without connecting to CST.
%
%   The example validates the CSV, applies the geometry constraints, and
%   writes results/example/planned_samples.csv so the expected schedule can
%   be inspected before a real sweep.
%
%   See also run_sweep, cstsweep.SweepRunner.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, "src"));

cfg = cstsweep.Config();
cfg.CsvPath = string(fullfile(root, "examples", "parameters_example.csv"));
cfg.OutputDir = string(fullfile(root, "results", "example"));
cfg.SamplesPerState = 5;
cfg.DryRun = true;

runner = cstsweep.SweepRunner(cfg);
summary = runner.run();

disp(summary);
end
