function cfg = loadConfig(configFile)
%LOADCONFIG Evaluate a configuration function and validate the result.
%
%   cfg = cstsweep.loadConfig("config/local_config.m") adds the containing
%   folder to the MATLAB path, calls the function, and checks that it returns
%   a cstsweep.Config object.
%
%   See also cstsweep.Config, run_sweep.

arguments
    configFile (1,1) string = "config/default_config.m"
end

if ~isfile(configFile)
    error('cstsweep:Config:FileNotFound', ...
        'Configuration file not found: %s', configFile);
end

[folder, name] = fileparts(char(configFile));
if ~isempty(folder)
    addpath(folder);
end

cfg = feval(name);
if ~isa(cfg, 'cstsweep.Config')
    error('cstsweep:Config:InvalidType', ...
        'Configuration function "%s" must return a cstsweep.Config object.', ...
        name);
end

cfg = cfg.validate();
end
