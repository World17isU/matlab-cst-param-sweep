function startup()
%STARTUP Add this package to the MATLAB path.
%
%   Run startup once per MATLAB session after changing into the repository
%   root. It only adds src/ to the path; no global settings are modified.
%
%   See also run_sweep.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, "src"));
fprintf('CST parameter sweep %s ready. Source: %s\n', ...
    cstsweep.version(), root);
end
