function summary = run_sweep(configFile)
%RUN_SWEEP Run a CST parameter sweep from a configuration file.
%
%   summary = run_sweep() runs config/default_config.m, which is a dry-run
%   plan over the bundled example table.
%
%   summary = run_sweep("config/local_config.m") runs a real sweep. Open the
%   CST project before calling this function unless StartCstIfNeeded is true.
%
%   The returned table has one row per attempted sample; the same table is
%   written to <OutputDir>/summary.csv.
%
%   See also cstsweep.SweepRunner, cstsweep.Config.

arguments
    configFile (1,1) string = "config/default_config.m"
end

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, "src"));

cfg = cstsweep.loadConfig(configFile);
runner = cstsweep.SweepRunner(cfg);
summary = runner.run();

if istable(summary)
    fprintf('\n%d row(s) recorded. Output folder: %s\n', ...
        height(summary), char(cfg.OutputDir));
end
end
