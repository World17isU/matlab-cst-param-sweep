classdef Config
    %CONFIG Validated configuration for a CST parameter sweep.
    %
    %   cfg = cstsweep.Config() returns defaults that run a dry-run plan on
    %   the bundled example table.
    %
    %   cfg = cstsweep.Config('CsvPath', "data/parameters.csv", ...
    %                         'OutputDir', "results/run-001") overrides
    %   individual options by name.
    %
    %   cfg = cfg.validate() checks the configuration and raises
    %   cstsweep:Config:Invalid when a problem is found.
    %
    %   See also cstsweep.SweepRunner, cstsweep.loadConfig.

    properties
        % Input CSV with one column per parameter and one row per sample.
        CsvPath (1,1) string = ""
        % Directory for sample files, log, summary, and archive.
        OutputDir (1,1) string = "results"
        % CST parameter names, in CSV column order.
        ParameterNames (1,:) string = ["R1", "R2", "R3", "R6", "R5", "T5"]
        % CST parameter that selects the model state.
        StateParameterName (1,1) string = "S"
        % Result tree path of the exported S-parameter.
        StateParameterPath (1,1) string = ...
            "1D Results\S-Parameters\SZmax(1),Zmax(1)"
        % Struct array with fields label, value, and prefix.
        States struct = struct([])
        % Number of CSV rows to run per state.
        SamplesPerState (1,1) double {mustBePositive, mustBeInteger} = 200
        % Limit every state to TestSampleCount rows.
        TestMode (1,1) logical = false
        % Number of rows per state in test mode.
        TestSampleCount (1,1) double {mustBePositive, mustBeInteger} = 1
        % Validate and plan without connecting to CST.
        DryRun (1,1) logical = false
        % Reuse existing absorption files instead of re-solving.
        SkipExistingResults (1,1) logical = false
        % Clear CST results before starting each solver run.
        ResetResultsBeforeRun (1,1) logical = true
        % CST solver object name, or "auto" to try FDSolver then Solver.
        SolverObject (1,1) string = "auto"
        % Per-sample solver timeout in seconds.
        SolverTimeoutSeconds (1,1) double {mustBePositive} = 600
        % Interval between solver status polls in seconds.
        PollIntervalSeconds (1,1) double {mustBePositive} = 5
        % Pause after Rebuild so CST can finish updating the model.
        RebuildSettleSeconds (1,1) double {mustBeNonnegative} = 2
        % Interpretation of the exported S-parameter values.
        SParameterFormat (1,1) string ...
            {mustBeMember(SParameterFormat, ["auto", "db", "linear"])} = "auto"
        % Struct array with fields first, second, relation, and reason.
        Constraints struct = struct([])
        % Keep the temporary ASCII export next to the results.
        KeepTemporaryFiles (1,1) logical = false
        % Write results.mat with configuration and raw curves.
        SaveMatFile (1,1) logical = true
        % Continue with the next sample when one sample fails.
        ContinueOnError (1,1) logical = true
        % Log file path; empty means <OutputDir>/sweep.log.
        LogFile (1,1) string = ""
        % Mirror log messages to the MATLAB command window.
        Verbose (1,1) logical = true
        % Launch CST when no running instance is found.
        StartCstIfNeeded (1,1) logical = false
        % Project opened when StartCstIfNeeded is true.
        ProjectPath (1,1) string = ""
    end

    methods
        function obj = Config(varargin)
            %CONFIG Create a configuration and apply name-value overrides.
            obj.States = cstsweep.Config.defaultStates();
            obj.Constraints = cstsweep.Config.defaultConstraints();

            if mod(numel(varargin), 2) ~= 0
                error('cstsweep:Config:InvalidArguments', ...
                    'Constructor arguments must be name-value pairs.');
            end
            for k = 1:2:numel(varargin)
                name = string(varargin{k});
                if ~isprop(obj, char(name))
                    error('cstsweep:Config:UnknownOption', ...
                        'Unknown configuration option "%s".', name);
                end
                obj.(char(name)) = varargin{k + 1};
            end
        end

        function obj = validate(obj)
            %VALIDATE Check the configuration and raise on inconsistencies.
            problems = strings(0, 1);
            names = string(obj.ParameterNames);

            if strlength(obj.CsvPath) == 0
                problems(end + 1) = "CsvPath must name a CSV file.";
            elseif ~isfile(obj.CsvPath)
                problems(end + 1) = "CsvPath does not exist: " + obj.CsvPath;
            end

            if strlength(obj.OutputDir) == 0
                problems(end + 1) = "OutputDir must not be empty.";
            end

            if isempty(names) || any(strlength(names) == 0)
                problems(end + 1) = ...
                    "ParameterNames must contain at least one non-empty name.";
            else
                if numel(unique(names)) ~= numel(names)
                    problems(end + 1) = "ParameterNames must be unique.";
                end
                for k = 1:numel(names)
                    if isempty(regexp(names(k), '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
                        problems(end + 1) = "ParameterNames must be valid " + ...
                            "identifiers for table output: " + names(k);
                    end
                end
                if any(names == obj.StateParameterName)
                    problems(end + 1) = ...
                        "StateParameterName must not also appear in ParameterNames.";
                end
            end

            if strlength(obj.StateParameterName) == 0
                problems(end + 1) = "StateParameterName must not be empty.";
            end
            if strlength(obj.StateParameterPath) == 0
                problems(end + 1) = "StateParameterPath must not be empty.";
            end

            problems = [problems; obj.validateStates()];
            problems = [problems; obj.validateConstraints(names)];

            if obj.StartCstIfNeeded && strlength(obj.ProjectPath) == 0
                problems(end + 1) = ...
                    "ProjectPath is required when StartCstIfNeeded is true.";
            end
            if obj.TestMode && obj.TestSampleCount < 1
                problems(end + 1) = "TestSampleCount must be at least 1.";
            end

            if ~isempty(problems)
                error('cstsweep:Config:Invalid', '%s', ...
                    strjoin(cellstr(problems), newline));
            end
        end
    end

    methods (Access = private)
        function problems = validateStates(obj)
            problems = strings(0, 1);
            states = obj.States;

            if ~isstruct(states) || isempty(states)
                problems(end + 1) = "States must be a non-empty struct array.";
                return
            end

            required = ["label", "value", "prefix"];
            present = string(fieldnames(states));
            missing = required(~ismember(required, present));
            if ~isempty(missing)
                problems(end + 1) = "States is missing field(s): " + ...
                    strjoin(cellstr(missing), ", ");
                return
            end

            for k = 1:numel(states)
                value = states(k).value;
                if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                    problems(end + 1) = sprintf( ...
                        'States(%d).value must be a finite numeric scalar.', k);
                end
                if strlength(string(states(k).label)) == 0
                    problems(end + 1) = sprintf( ...
                        'States(%d).label must not be empty.', k);
                end
                prefix = string(states(k).prefix);
                if strlength(prefix) == 0 || ...
                        ~isempty(regexp(prefix, '[<>:"/\\|?*]', 'once'))
                    problems(end + 1) = sprintf( ...
                        'States(%d).prefix must be a valid file prefix.', k);
                end
            end

            prefixes = string({states.prefix});
            if numel(unique(prefixes)) ~= numel(prefixes)
                problems(end + 1) = "States.prefix values must be unique.";
            end
            labels = string({states.label});
            if numel(unique(labels)) ~= numel(labels)
                problems(end + 1) = "States.label values must be unique.";
            end
        end

        function problems = validateConstraints(obj, names)
            problems = strings(0, 1);
            constraints = obj.Constraints;

            if isempty(constraints)
                return
            end
            if ~isstruct(constraints)
                problems(end + 1) = "Constraints must be a struct array.";
                return
            end

            required = ["first", "second", "relation", "reason"];
            present = string(fieldnames(constraints));
            missing = required(~ismember(required, present));
            if ~isempty(missing)
                problems(end + 1) = "Constraints is missing field(s): " + ...
                    strjoin(cellstr(missing), ", ");
                return
            end

            for k = 1:numel(constraints)
                c = constraints(k);
                if ~any(names == string(c.first)) || ...
                        ~any(names == string(c.second))
                    problems(end + 1) = sprintf( ...
                        ['Constraints(%d) refers to a parameter that is not ' ...
                         'listed in ParameterNames.'], k);
                end
                if ~any(string(c.relation) == ["gt", "ge", "lt", "le"])
                    problems(end + 1) = sprintf( ...
                        'Constraints(%d).relation must be gt, ge, lt, or le.', k);
                end
            end
        end
    end

    methods (Static)
        function states = defaultStates()
            %DEFAULTSTATES Broadband and narrowband states from the original model.
            states = struct( ...
                "label", {"Broadband", "Narrowband"}, ...
                "value", {80000, 150}, ...
                "prefix", {"K", "F"});
        end

        function constraints = defaultConstraints()
            %DEFAULTCONSTRAINTS Geometry rules enforced before each solve.
            constraints = struct( ...
                "first", {"R2", "R5"}, ...
                "second", {"R3", "R6"}, ...
                "relation", {"gt", "gt"}, ...
                "reason", {"R2<=R3", "R5<=R6"});
        end
    end
end
