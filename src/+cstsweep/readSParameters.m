function data = readSParameters(filePath, formatHint)
%READSPARAMETERS Parse a CST ASCII export of a reflection coefficient.
%
%   data = cstsweep.readSParameters(filePath) reads a two-column export
%   (frequency, S-parameter) and returns a struct with fields frequency,
%   values, magnitude, format, and unit.
%
%   formatHint selects how values are interpreted: "auto" (default), "db", or
%   "linear". Automatic detection treats values in [0, 1] as linear magnitude
%   and everything else as dB.
%
%   Comment lines starting with #, %, //, or * are ignored, and whitespace,
%   commas, or semicolons are accepted as column separators.
%
%   See also cstsweep.computeAbsorption, cstsweep.Session.exportSParameters.

arguments
    filePath (1,1) string
    formatHint (1,1) string ...
        {mustBeMember(formatHint, ["auto", "db", "linear"])} = "auto"
end

if ~isfile(filePath)
    error('cstsweep:SParams:FileNotFound', ...
        'S-parameter file not found: %s', filePath);
end

text = fileread(char(filePath));
lines = regexp(text, '\r?\n', 'split');

frequency = zeros(0, 1);
values = zeros(0, 1);

for k = 1:numel(lines)
    line = strtrim(lines{k});
    if isempty(line) || any(startsWith(line, {'#', '%', '//', '*'}))
        continue
    end

    tokens = regexp(line, '[\s,;]+', 'split');
    tokens = tokens(~cellfun(@isempty, tokens));
    if numel(tokens) < 2
        continue
    end

    f = str2double(tokens{1});
    v = str2double(tokens{2});
    if isnan(f) || isnan(v)
        continue
    end

    frequency(end + 1, 1) = f; %#ok<AGROW>
    values(end + 1, 1) = v; %#ok<AGROW>
end

if numel(frequency) < 2
    error('cstsweep:SParams:NoData', ...
        'No numeric frequency/S-parameter rows found in %s.', filePath);
end

[frequency, order] = sort(frequency);
values = values(order);

resolvedFormat = formatHint;
if resolvedFormat == "auto"
    resolvedFormat = cstsweep.detectSParameterFormat(values);
end

magnitude = values;
if resolvedFormat == "db"
    magnitude = 10 .^ (values ./ 20);
end

data.frequency = frequency;
data.values = values;
data.magnitude = magnitude;
data.format = resolvedFormat;
data.unit = cstsweep.detectFrequencyUnit(lines);
end
