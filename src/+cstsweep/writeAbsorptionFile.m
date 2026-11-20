function writeAbsorptionFile(filePath, frequency, absorption)
%WRITEABSORPTIONFILE Write a tab-separated frequency/absorptance table.
%
%   cstsweep.writeAbsorptionFile(filePath, frequency, absorption) writes one
%   row per frequency point with scientific notation and no header, matching
%   the format read by cstsweep.readAbsorptionFile.
%
%   See also cstsweep.readAbsorptionFile.

arguments
    filePath (1,1) string
    frequency (:,1) double
    absorption (:,1) double
end

if numel(frequency) ~= numel(absorption)
    error('cstsweep:Absorption:SizeMismatch', ...
        'Frequency and absorption must have the same number of elements.');
end

fid = fopen(char(filePath), 'w');
if fid < 0
    error('cstsweep:Absorption:WriteFailed', ...
        'Could not open %s for writing.', filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

data = [frequency(:), absorption(:)];
fprintf(fid, '%.10e\t%.10e\n', data');
end
