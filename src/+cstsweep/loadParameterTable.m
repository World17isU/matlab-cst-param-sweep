function data = loadParameterTable(csvPath, parameterNames)
%LOADPARAMETERTABLE Read and validate the sweep parameter table.
%
%   data = cstsweep.loadParameterTable(csvPath, names) reads a CSV file with
%   one column per parameter and one row per sample. The returned struct has
%   fields numRows, names, values (numRows-by-numel(names)), columns, and
%   source.
%
%   Errors use the cstsweep:ParamTable:* identifier family.
%
%   See also cstsweep.Config, cstsweep.SweepRunner.

arguments
    csvPath (1,1) string
    parameterNames (1,:) string
end

if ~isfile(csvPath)
    error('cstsweep:ParamTable:FileNotFound', ...
        'Parameter table not found: %s', csvPath);
end

table_ = readtable(char(csvPath), 'VariableNamingRule', 'preserve');
if height(table_) == 0
    error('cstsweep:ParamTable:Empty', ...
        'Parameter table has no data rows: %s', csvPath);
end

columns = string(table_.Properties.VariableNames);
missing = parameterNames(~ismember(parameterNames, columns));
if ~isempty(missing)
    error('cstsweep:ParamTable:MissingColumns', ...
        'Missing parameter column(s): %s. Available columns: %s.', ...
        strjoin(cellstr(missing), ", "), strjoin(cellstr(columns), ", "));
end

values = zeros(height(table_), numel(parameterNames));
for k = 1:numel(parameterNames)
    column = table_.(char(parameterNames(k)));
    if isnumeric(column) || islogical(column)
        values(:, k) = double(column);
    else
        values(:, k) = str2double(string(column));
    end
end

badRows = find(any(~isfinite(values), 2));
if ~isempty(badRows)
    error('cstsweep:ParamTable:NonNumericValues', ...
        'Non-numeric or missing values in table row(s): %s.', ...
        mat2str(badRows(:)'));
end

data.numRows = height(table_);
data.names = parameterNames;
data.values = values;
data.columns = columns;
data.source = csvPath;
end
