classdef Session < handle
    %SESSION Thin wrapper around the CST Studio Suite COM automation API.
    %
    %   The session owns the COM handles, the parameter snapshot, and the
    %   solver lifecycle. Its destructor restores the snapshot and releases
    %   the handles, so a failed sweep leaves the CST project in its original
    %   state.
    %
    %   The class deliberately exposes only the operations the runner needs:
    %   reading and writing double parameters, rebuilding, starting and
    %   waiting for the solver, and exporting the S-parameter result.
    %
    %   See also cstsweep.SweepRunner, cstsweep.Config.

    properties (SetAccess = private)
        % CST application COM object.
        App
        % CST 3D model COM object.
        Model
        % Name of the solver object that was started.
        SolverName (1,1) string = ""
        % Result tree path used for export and completion polling.
        TreePath (1,1) string = ""
    end

    properties (Access = private)
        Log
        SolverObject (1,1) string = "auto"
        SnapshotNames (1,:) string = strings(1, 0)
        SnapshotValues double = []
        Restored (1,1) logical = false
        Deleted (1,1) logical = false
    end

    methods
        function obj = Session(cfg, log)
            %SESSION Connect to CST and activate the configured project.
            arguments
                cfg (1,1) cstsweep.Config
                log = []
            end

            obj.Log = log;
            obj.SolverObject = cfg.SolverObject;
            obj.TreePath = cfg.StateParameterPath;

            obj.App = cstsweep.Session.connect(cfg);
            try
                obj.Model = cstsweep.Session.activate(obj.App, cfg);
            catch ME
                try
                    release(obj.App);
                catch
                end
                rethrow(ME);
            end
        end

        function value = getParameter(obj, name)
            %GETPARAMETER Evaluate a CST double parameter.
            try
                raw = obj.Model.invoke('Evaluate', char(name));
                value = double(raw);
            catch ME
                error('cstsweep:Session:ParameterReadFailed', ...
                    'Could not evaluate parameter "%s": %s', name, ME.message);
            end
            if ~isscalar(value) || ~isfinite(value)
                error('cstsweep:Session:ParameterReadFailed', ...
                    'Parameter "%s" did not evaluate to a finite scalar.', name);
            end
        end

        function setParameter(obj, name, value)
            %SETPARAMETER Store a double parameter in the CST model.
            try
                obj.Model.invoke('StoreDoubleParameter', char(name), double(value));
            catch ME
                error('cstsweep:Session:ParameterWriteFailed', ...
                    'Could not write parameter "%s": %s', name, ME.message);
            end
        end

        function snapshotParameters(obj, names)
            %SNAPSHOTPARAMETERS Record current values so they can be restored.
            values = zeros(1, numel(names));
            for k = 1:numel(names)
                values(k) = obj.getParameter(names(k));
            end
            obj.SnapshotNames = names;
            obj.SnapshotValues = values;
            obj.Restored = false;
        end

        function restoreParameters(obj)
            %RESTOREPARAMETERS Write the snapshot back and rebuild once.
            if obj.Restored || isempty(obj.SnapshotNames)
                return
            end
            obj.Restored = true;

            for k = 1:numel(obj.SnapshotNames)
                try
                    obj.setParameter(obj.SnapshotNames(k), obj.SnapshotValues(k));
                catch ME
                    obj.warn("Could not restore parameter %s: %s", ...
                        obj.SnapshotNames(k), ME.message);
                end
            end
            try
                obj.rebuild(0);
            catch ME
                obj.warn("Rebuild after restore failed: %s", ME.message);
            end
        end

        function rebuild(obj, settleSeconds)
            %REBUILD Rebuild the model and optionally wait for CST to settle.
            arguments
                obj (1,1) cstsweep.Session
                settleSeconds (1,1) double {mustBeNonnegative} = 0
            end
            try
                obj.Model.invoke('Rebuild');
            catch ME
                error('cstsweep:Session:RebuildFailed', ...
                    'Model rebuild failed: %s', ME.message);
            end
            if settleSeconds > 0
                pause(settleSeconds);
            end
        end

        function resetResults(obj)
            %RESETRESULTS Clear previous results before a new solver run.
            try
                obj.Model.invoke('ResetResults');
            catch ME
                obj.warn("ResetResults is not available: %s", ME.message);
            end
        end

        function startSolver(obj)
            %STARTSOLVER Start the configured solver, trying fallbacks.
            candidates = obj.solverCandidates();
            lastMessage = "no solver object could be started";

            for k = 1:numel(candidates)
                solver = [];
                try
                    solver = obj.Model.invoke(char(candidates(k)));
                catch ME
                    lastMessage = string(ME.message);
                    continue
                end
                if ~iscom(solver)
                    lastMessage = "solver object is not available";
                    continue
                end
                try
                    solver.invoke('Start');
                    obj.SolverName = candidates(k);
                    release(solver);
                    pause(1);
                    return
                catch ME
                    lastMessage = string(ME.message);
                    try
                        release(solver);
                    catch
                    end
                end
            end

            error('cstsweep:Session:SolverStartFailed', ...
                'Could not start a CST solver: %s', lastMessage);
        end

        function stopSolver(obj)
            %STOPSOLVER Request a stop after a timeout; failures are ignored.
            if strlength(obj.SolverName) == 0
                return
            end
            try
                solver = obj.Model.invoke(char(obj.SolverName));
                if ~iscom(solver)
                    return
                end
                cleanup = onCleanup(@() release(solver)); %#ok<NASGU>
                solver.invoke('Stop');
            catch
            end
        end

        function status = waitForSolver(obj, timeoutSeconds, pollSeconds)
            %WAITFORSOLVER Block until the solver finishes or the timeout expires.
            %
            %   Returns a struct with fields completed, elapsedSeconds, and
            %   method. When no CST status method responds, completion is
            %   inferred from the presence of the result tree item.
            arguments
                obj (1,1) cstsweep.Session
                timeoutSeconds (1,1) double {mustBePositive}
                pollSeconds (1,1) double {mustBePositive}
            end

            status = struct( ...
                'completed', false, ...
                'elapsedSeconds', 0, ...
                'method', "");
            started = tic;

            pause(min(2, pollSeconds));

            usingTreeFallback = false;
            while toc(started) < timeoutSeconds
                [running, known, probe] = obj.solverRunning();
                if known
                    if ~running
                        status.completed = true;
                        status.method = probe;
                        status.elapsedSeconds = toc(started);
                        return
                    end
                else
                    if ~usingTreeFallback
                        usingTreeFallback = true;
                        obj.warn(['No solver status method responded; ' ...
                            'falling back to result tree polling.']);
                    end
                    if obj.resultTreeItemExists()
                        status.completed = true;
                        status.method = "ResultTree";
                        status.elapsedSeconds = toc(started);
                        return
                    end
                end
                pause(pollSeconds);
            end

            status.elapsedSeconds = toc(started);
        end

        function exportSParameters(obj, targetFile)
            %EXPORTSPARAMETERS Export the selected result as ASCII version 2010.
            try
                obj.Model.invoke('SelectTreeItem', char(obj.TreePath));
                exporter = obj.Model.invoke('ASCIIExport');
                if ~iscom(exporter)
                    error('cstsweep:Session:ExportFailed', ...
                        'The ASCII exporter is not available.');
                end
                cleanup = onCleanup(@() release(exporter)); %#ok<NASGU>
                exporter.invoke('Reset');
                exporter.invoke('SetVersion', '2010');
                exporter.invoke('FileName', char(targetFile));
                exporter.invoke('Execute');
            catch ME
                error('cstsweep:Session:ExportFailed', ...
                    'Could not export "%s": %s', obj.TreePath, ME.message);
            end
        end

        function delete(obj)
            %DELETE Restore parameters, then release the COM handles.
            if obj.Deleted
                return
            end
            obj.Deleted = true;

            try
                obj.restoreParameters();
            catch
            end
            try
                release(obj.Model);
            catch
            end
            try
                release(obj.App);
            catch
            end
        end
    end

    methods (Access = private)
        function names = solverCandidates(obj)
            if obj.SolverObject == "auto"
                names = ["FDSolver", "Solver"];
            else
                names = obj.SolverObject;
            end
        end

        function [running, known, probe] = solverRunning(obj)
            %SOLVERRUNNING Query the solver status with several fallbacks.
            running = false;
            known = false;
            probe = "";

            name = obj.SolverName;
            if strlength(name) == 0
                name = obj.solverCandidates();
                name = name(1);
            end

            solver = [];
            try
                solver = obj.Model.invoke(char(name));
            catch
                return
            end
            if ~iscom(solver)
                return
            end
            cleanup = onCleanup(@() release(solver)); %#ok<NASGU>

            probes = ["GetSolverStatus", "IsRunning", "Status"];
            for k = 1:numel(probes)
                try
                    raw = solver.invoke(char(probes(k)));
                catch
                    continue
                end
                verdict = cstsweep.Session.interpretStatus(raw);
                if ~isempty(verdict)
                    running = verdict;
                    known = true;
                    probe = probes(k);
                    return
                end
            end
        end

        function tf = resultTreeItemExists(obj)
            tf = false;
            if strlength(obj.TreePath) == 0
                return
            end
            try
                obj.Model.invoke('SelectTreeItem', char(obj.TreePath));
                tf = true;
            catch
            end
        end

        function warn(obj, fmt, varargin)
            if ~isempty(obj.Log)
                obj.Log.warn(fmt, varargin{:});
            end
        end
    end

    methods (Static, Access = private)
        function app = connect(cfg)
            try
                app = actxGetRunningServer('CSTStudio.application');
            catch ME
                if ~cfg.StartCstIfNeeded
                    error('cstsweep:Session:NotRunning', ...
                        ['CST Studio Suite is not running. Start CST, open ' ...
                         'the project, and run the sweep again. Set ' ...
                         'StartCstIfNeeded and ProjectPath to launch CST ' ...
                         'automatically. (%s)'], ME.message);
                end
                app = actxserver('CSTStudio.application');
            end
        end

        function model = activate(app, cfg)
            try
                if strlength(cfg.ProjectPath) > 0
                    model = app.invoke('OpenFile', char(cfg.ProjectPath));
                else
                    model = app.invoke('Active3D');
                end
            catch ME
                error('cstsweep:Session:NoActiveProject', ...
                    'Could not activate a CST 3D project: %s', ME.message);
            end

            if ~iscom(model)
                error('cstsweep:Session:NoActiveProject', ...
                    ['No CST 3D project is open. Open the project in CST ' ...
                     'before running the sweep.']);
            end
        end

        function verdict = interpretStatus(raw)
            %INTERPRETSTATUS Map a CST status reply to true/false/empty.
            verdict = [];

            if islogical(raw) && isscalar(raw)
                verdict = raw;
                return
            end
            if isnumeric(raw) && isscalar(raw)
                verdict = raw ~= 0;
                return
            end
            if ~(ischar(raw) || isstring(raw))
                return
            end

            text = lower(strtrim(string(raw)));
            if any(contains(text, ["not running", "idle", "finished", "done", ...
                    "stopped", "ready"]))
                verdict = false;
            elseif any(contains(text, ["running", "solving", "in progress", "busy"]))
                verdict = true;
            end
        end
    end
end
