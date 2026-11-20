function format = detectSParameterFormat(values)
%DETECTSPARAMETERFORMAT Classify exported values as dB or linear magnitude.
%
%   format = cstsweep.detectSParameterFormat(values) returns "linear" when
%   every value lies in [0, 1] (with a small tolerance for numerical noise),
%   and "db" otherwise. Passive reflection coefficients cannot exceed unity in
%   linear form, so larger values are read as dB.
%
%   The heuristic is ambiguous for dB values between -1 and 0; set
%   cfg.SParameterFormat explicitly in that case.
%
%   See also cstsweep.readSParameters.

values = values(:);

if isempty(values)
    format = "linear";
elseif all(values >= -1e-9) && all(values <= 1 + 1e-6)
    format = "linear";
else
    format = "db";
end
end
