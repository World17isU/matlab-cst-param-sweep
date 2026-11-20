function [frequency, absorption] = readAbsorptionFile(filePath)
%READABSORPTIONFILE Read a two-column absorption file written by this package.
%
%   [frequency, absorption] = cstsweep.readAbsorptionFile(filePath) reads the
%   tab-separated frequency/absorptance table produced by
%   cstsweep.writeAbsorptionFile, dropping rows with non-finite values.
%
%   See also cstsweep.writeAbsorptionFile.

arguments
    filePath (1,1) string
end

if ~isfile(filePath)
    error('cstsweep:Absorption:FileNotFound', ...
        'Absorption file not found: %s', filePath);
end

matrix = readmatrix(char(filePath));
if isempty(matrix) || size(matrix, 2) < 2
    error('cstsweep:Absorption:NoData', ...
        'No two-column data found in %s.', filePath);
end

frequency = matrix(:, 1);
absorption = matrix(:, 2);

valid = isfinite(frequency) & isfinite(absorption);
frequency = frequency(valid);
absorption = absorption(valid);

if numel(frequency) < 2
    error('cstsweep:Absorption:TooFewPoints', ...
        'At least two valid data rows are required in %s.', filePath);
end
end
