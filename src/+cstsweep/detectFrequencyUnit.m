function unit = detectFrequencyUnit(lines)
%DETECTFREQUENCYUNIT Find the frequency unit in an ASCII export header.
%
%   unit = cstsweep.detectFrequencyUnit(lines) scans the first lines of a CST
%   export for a THz, GHz, MHz, kHz, or Hz token and returns it as a string.
%   An empty string is returned when no unit is found.
%
%   See also cstsweep.readSParameters.

unit = "";

limit = min(numel(lines), 40);
for k = 1:limit
    token = regexp(lines{k}, '(THz|GHz|MHz|kHz|Hz)', 'tokens', 'once');
    if ~isempty(token)
        unit = string(token{1});
        return
    end
end
end
