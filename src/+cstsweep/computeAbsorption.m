function result = computeAbsorption(frequency, magnitude)
%COMPUTEABSORPTION Absorptance of a metal-backed layer from |S11|.
%
%   result = cstsweep.computeAbsorption(frequency, magnitude) returns a struct
%   with fields frequency, absorption, peakAbsorption, peakFrequency, and
%   meanAbsorption. Absorptance is A = 1 - |S11|^2, clipped to [0, 1].
%
%   The formula assumes negligible transmission; see README.md.
%
%   See also cstsweep.readSParameters.

frequency = frequency(:);
magnitude = magnitude(:);

if numel(frequency) ~= numel(magnitude)
    error('cstsweep:Absorption:SizeMismatch', ...
        'Frequency and magnitude must have the same number of elements.');
end
if numel(frequency) < 2
    error('cstsweep:Absorption:TooFewPoints', ...
        'At least two frequency points are required.');
end

magnitude = min(max(magnitude, 0), 1);
absorption = 1 - magnitude .^ 2;
absorption = min(max(absorption, 0), 1);

[peak, index] = max(absorption);

result.frequency = frequency;
result.absorption = absorption;
result.peakAbsorption = peak;
result.peakFrequency = frequency(index);
result.meanAbsorption = mean(absorption);
end
