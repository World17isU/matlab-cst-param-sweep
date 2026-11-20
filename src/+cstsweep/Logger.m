classdef Logger < handle
    %LOGGER Timestamped console and file logging.
    %
    %   log = cstsweep.Logger("results/sweep.log", true) appends to the file
    %   and mirrors INFO messages to the command window.
    %
    %   See also cstsweep.SweepRunner.

    properties (SetAccess = private)
        % Destination file; empty disables file logging.
        FilePath (1,1) string = ""
        % Mirror INFO messages to the command window.
        Verbose (1,1) logical = true
    end

    properties (Access = private)
        Fid double = -1
    end

    methods
        function obj = Logger(filePath, verbose)
            %LOGGER Open the log file for appending.
            arguments
                filePath (1,1) string = ""
                verbose (1,1) logical = true
            end

            obj.FilePath = filePath;
            obj.Verbose = verbose;

            if strlength(filePath) == 0
                return
            end
            folder = fileparts(char(filePath));
            if ~isempty(folder) && ~isfolder(folder)
                mkdir(folder);
            end
            obj.Fid = fopen(char(filePath), 'a');
            if obj.Fid < 0
                warning('cstsweep:Logger:OpenFailed', ...
                    'Could not open log file: %s', filePath);
                obj.Fid = -1;
            end
        end

        function info(obj, fmt, varargin)
            %INFO Log an informational message.
            obj.write("INFO", fmt, varargin{:});
        end

        function warn(obj, fmt, varargin)
            %WARN Log a warning.
            obj.write("WARN", fmt, varargin{:});
        end

        function err(obj, fmt, varargin)
            %ERR Log an error message.
            obj.write("ERROR", fmt, varargin{:});
        end

        function section(obj, fmt, varargin)
            %SECTION Log a banner between two rules.
            text = sprintf(fmt, varargin{:});
            width = min(72, max(20, strlength(text) + 4));
            rule = repmat('=', 1, width);
            obj.write("INFO", "%s\n%s\n%s", rule, text, rule);
        end

        function delete(obj)
            %DELETE Close the log file.
            if obj.Fid >= 0
                fclose(obj.Fid);
                obj.Fid = -1;
            end
        end
    end

    methods (Access = private)
        function write(obj, level, fmt, varargin)
            message = sprintf(fmt, varargin{:});
            stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            line = sprintf('[%s] %-5s %s', stamp, level, message);

            if obj.Fid >= 0
                fprintf(obj.Fid, '%s\n', line);
            end
            if obj.Verbose || level ~= "INFO"
                fprintf('%s\n', line);
            end
        end
    end
end
