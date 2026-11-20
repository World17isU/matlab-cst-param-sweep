classdef SweepRunner < handle
    %SWEEPRUNNER Orchestrate a CST parameter sweep.
    %
    %   runner = cstsweep.SweepRunner(cfg) validates the configuration.
    %   summary = runner.run() executes the sweep (or a dry-run plan) and
    %   returns a table with one row per attempted sample.
    %
    %   The runner owns a cstsweep.Session, so the CST model is restored and
    %   the COM handles are released when run() returns or fails.
    %
    %   See also cstsweep.Config, cstsweep.Session.

    properties (SetAccess = private)
        Config
    end

    properties (Access = private)
        Log
        Session
    end

    methods
        function obj = SweepRunner(cfg)
            %SWEEPRUNNER Validate and store the configuration.
            arguments
                cfg (1,1) cstsweep.Config
            end
            obj.Config = cfg.validate();
        end

        function summary = run(obj)
            %RUN Execute the sweep and return the summary table.
            cfg = obj.Config;
            data = cstsweep.loadParameterTable(cfg.CsvPath, cfg.ParameterNames);

            if ~isfolder(cfg.OutputDir)
                mkdir(cfg.OutputDir);
            end

            logPath = cfg.LogFile;
            if strlength(logPath) == 0
                logPath = fullfile(cfg.OutputDir, "sweep.log");
            end
            obj.Log = cstsweep.Logger(logPath, cfg.Verbose);
            obj.Log.info("CST parameter sweep %s", cstsweep.version());
            obj.Log.info("Parameter table: %s (%d row(s))", ...
                data.source, data.numRows);

            sampleCount = obj.resolveSampleCount(data.numRows);

            if cfg.DryRun
                summary = obj.plan(data, sampleCount);
                return
            end

            obj.Session = cstsweep.Session(cfg, obj.Log);
            cleanup = onCleanup(@() obj.closeSession()); %#ok<NASGU>
            obj.Session.snapshotParameters( ...
                [cfg.ParameterNames, cfg.StateParameterName]);
            snapshot = obj.Session.getSnapshot();
            obj.Log.info("Initial parameters: %s", ...
                obj.formatParameters(snapshot.values, snapshot.names));

            records = repmat(obj.emptyRecord(cfg), 0, 1);

            for s = 1:numel(cfg.States)
                state = cfg.States(s);
                obj.Log.section(sprintf('%s state (S = %g, prefix %s)', ...
                    char(state.label), state.value, char(state.prefix)));

                try
                    obj.Session.setParameter(cfg.StateParameterName, state.value);
                    obj.Session.rebuild(cfg.RebuildSettleSeconds);
                catch ME
                    obj.Log.err("State setup failed: %s", ME.message);
                    if ~cfg.ContinueOnError
                        rethrow(ME);
                    end
                    continue
                end

                for i = 1:sampleCount
                    record = obj.runSample(state, i, data.values(i, :), cfg);
                    records(end + 1, 1) = record; %#ok<AGROW>
                end
            end

            obj.Session.restoreParameters();
            obj.closeSession();

            summary = obj.writeResults(records, cfg, snapshot);
        end
    end

    methods (Access = private)
        function record = runSample(obj, state, index, values, cfg)
            %RUNSAMPLE Validate, solve, export, and record one parameter set.
            started = tic;

            record = obj.emptyRecord(cfg);
            record.State = string(state.label);
            record.StateValue = state.value;
            record.Sample = index;
            record.Parameters = values;
            record.OutputFile = fullfile(cfg.OutputDir, ...
                sprintf('%s_sample_%03d_absorption.txt', ...
                char(state.prefix), index));

            obj.Log.info("Sample %03d [%s]: %s", index, char(state.label), ...
                obj.formatParameters(values, cfg.ParameterNames));

            if cfg.SkipExistingResults && isfile(record.OutputFile)
                try
                    [frequency, absorption] = ...
                        cstsweep.readAbsorptionFile(record.OutputFile);
                    record = obj.fillFromAbsorption( ...
                        record, frequency, absorption);
                    record.Reason = "reused existing result";
                    record.ElapsedSeconds = toc(started);
                    obj.Log.info("Reused %s", record.OutputFile);
                    return
                catch ME
                    obj.Log.warn( ...
                        "Existing result could not be reused (%s); re-solving.", ...
                        ME.message);
                end
            end

            [ok, reason] = cstsweep.evaluateConstraints( ...
                values, cfg.ParameterNames, cfg.Constraints);
            if ~ok
                record.Reason = reason;
                record.ElapsedSeconds = toc(started);
                obj.Log.info("Skipped: %s", reason);
                return
            end

            try
                obj.applyParameters(values, cfg);
                if cfg.ResetResultsBeforeRun
                    obj.Session.resetResults();
                end
                obj.Session.startSolver();
            catch ME
                record.Reason = "setup failed: " + string(ME.message);
                record.ElapsedSeconds = toc(started);
                obj.Log.err("Sample %03d setup failed: %s", index, ME.message);
                obj.handleSampleError(ME, cfg);
                return
            end

            waitStatus = obj.Session.waitForSolver( ...
                cfg.SolverTimeoutSeconds, cfg.PollIntervalSeconds);
            if ~waitStatus.completed
                record.Reason = "solver timeout";
                record.ElapsedSeconds = toc(started);
                obj.Log.warn( ...
                    "Sample %03d timed out after %.1f s (%s).", ...
                    index, waitStatus.elapsedSeconds, waitStatus.method);
                obj.Session.stopSolver();
                return
            end

            tempFile = fullfile(cfg.OutputDir, ...
                sprintf(".tmp_sparam_%03d.txt", index));
            cleanup = onCleanup(@() obj.removeFile(tempFile, cfg)); %#ok<NASGU>

            try
                obj.Session.exportSParameters(tempFile);
                sparam = cstsweep.readSParameters(tempFile, cfg.SParameterFormat);
                absorption = cstsweep.computeAbsorption( ...
                    sparam.frequency, sparam.magnitude);
                cstsweep.writeAbsorptionFile(record.OutputFile, ...
                    absorption.frequency, absorption.absorption);
                record = obj.fillFromAbsorption( ...
                    record, absorption.frequency, absorption.absorption);
                record.Unit = sparam.unit;
            catch ME
                record.Reason = "export failed: " + string(ME.message);
                record.ElapsedSeconds = toc(started);
                obj.Log.err("Sample %03d export failed: %s", index, ME.message);
                obj.handleSampleError(ME, cfg);
                return
            end

            record.ElapsedSeconds = toc(started);
            obj.Log.info( ...
                "Peak absorptance %.4f at %.4f %s (%.1f s, %s)", ...
                record.PeakAbsorption, record.PeakFrequency, ...
                sparam.unit, record.ElapsedSeconds, waitStatus.method);
        end

        function applyParameters(obj, values, cfg)
            %APPLYPARAMETERS Write the row and rebuild the model.
            for k = 1:numel(cfg.ParameterNames)
                obj.Session.setParameter(cfg.ParameterNames(k), values(k));
            end
            obj.Session.rebuild(cfg.RebuildSettleSeconds);
        end

        function record = fillFromAbsorption(~, record, frequency, absorption)
            %FILLFROMABSORPTION Copy curves and peak metrics into a record.
            record.Frequency = frequency(:);
            record.Absorption = absorption(:);

            [peak, index] = max(absorption);
            record.PeakAbsorption = peak;
            record.PeakFrequency = frequency(index);
            record.MeanAbsorption = mean(absorption);
            record.Valid = true;
            record.Reason = "";
        end

        function handleSampleError(~, ME, cfg)
            %HANDLESAMPLEERROR Abort or continue after a per-sample failure.
            if ~cfg.ContinueOnError
                rethrow(ME);
            end
        end

        function removeFile(~, filePath, cfg)
            %REMOVEFILE Delete the temporary export unless it is kept.
            if ~cfg.KeepTemporaryFiles && isfile(filePath)
                delete(filePath);
            end
        end

        function text = formatParameters(~, values, names)
            %FORMATPARAMETERS Render a parameter row for the log.
            parts = strings(1, numel(names));
            for k = 1:numel(names)
                parts(k) = sprintf('%s=%.4g', char(names(k)), values(k));
            end
            text = strjoin(cellstr(parts), ", ");
        end

        function record = emptyRecord(~, cfg)
            %EMPTYRECORD Template for one sample record.
            record = struct( ...
                'State', "", ...
                'StateValue', NaN, ...
                'Sample', 0, ...
                'Valid', false, ...
                'Reason', "", ...
                'PeakAbsorption', NaN, ...
                'PeakFrequency', NaN, ...
                'MeanAbsorption', NaN, ...
                'OutputFile', "", ...
                'Unit', "", ...
                'ElapsedSeconds', NaN, ...
                'Parameters', zeros(1, numel(cfg.ParameterNames)), ...
                'Frequency', zeros(0, 1), ...
                'Absorption', zeros(0, 1));
        end

        function count = resolveSampleCount(obj, available)
            %RESOLVESAMPLECOUNT Apply test mode and clamp to the table size.
            cfg = obj.Config;
            if cfg.TestMode
                count = min(cfg.TestSampleCount, available);
                obj.Log.info( ...
                    "Test mode: %d of %d sample(s) per state.", ...
                    count, available);
            else
                count = min(cfg.SamplesPerState, available);
                obj.Log.info( ...
                    "%d of %d sample(s) per state.", count, available);
            end

            if count < 1
                error('cstsweep:Runner:NoSamples', 'No samples to run.');
            end
        end

        function summary = plan(obj, data, sampleCount)
            %PLAN Build the dry-run schedule without touching CST.
            cfg = obj.Config;
            rows = cell(numel(cfg.States) * sampleCount, 1);
            index = 0;

            for s = 1:numel(cfg.States)
                state = cfg.States(s);
                for i = 1:sampleCount
                    values = data.values(i, :);
                    [ok, reason] = cstsweep.evaluateConstraints( ...
                        values, cfg.ParameterNames, cfg.Constraints);

                    index = index + 1;
                    row = table(string(state.label), state.value, i, ok, reason, ...
                        'VariableNames', ...
                        {'state', 'state_value', 'sample', 'eligible', 'reason'});
                    for k = 1:numel(cfg.ParameterNames)
                        row.(char(cfg.ParameterNames(k))) = values(k);
                    end
                    rows{index} = row; %#ok<AGROW>
                end
            end

            summary = vertcat(rows{:});
            planFile = fullfile(cfg.OutputDir, "planned_samples.csv");
            writetable(summary, char(planFile));
            obj.Log.info("Dry run: %d planned sample(s), %d eligible.", ...
                height(summary), nnz(summary.eligible));
            obj.Log.info("Plan written to %s", planFile);
        end

        function summary = writeResults(obj, records, cfg, snapshot)
            %WRITERESULTS Persist the summary CSV and the results archive.
            summary = obj.buildSummaryTable(records, cfg);
            summaryPath = fullfile(cfg.OutputDir, "summary.csv");
            writetable(summary, char(summaryPath));
            obj.Log.info("Summary written to %s", summaryPath);

            if cfg.SaveMatFile
                archive = struct();
                archive.generatedAt = datetime('now');
                archive.packageVersion = cstsweep.version();
                archive.config = cfg;
                archive.snapshot = snapshot;
                archive.records = records;
                archive.summary = summary;
                matPath = fullfile(cfg.OutputDir, "results.mat");
                save(char(matPath), '-struct', 'archive');
                obj.Log.info("Archive written to %s", matPath);
            end

            obj.Log.info("Finished: %d valid sample(s) of %d attempted.", ...
                nnz([records.Valid]), numel(records));
        end

        function summary = buildSummaryTable(~, records, cfg)
            %BUILDSUMMARYTABLE Convert sample records into a flat table.
            count = numel(records);
            state = string({records.State})';
            sample = [records.Sample]';
            valid = [records.Valid]';
            reason = string({records.Reason})';
            peak = [records.PeakAbsorption]';
            peakFrequency = [records.PeakFrequency]';
            meanAbsorption = [records.MeanAbsorption]';
            unit = string({records.Unit})';
            outputFile = string({records.OutputFile})';
            elapsed = [records.ElapsedSeconds]';

            parameters = reshape( ...
                [records.Parameters], numel(cfg.ParameterNames), count)';
            parameterTable = array2table(parameters, ...
                'VariableNames', cellstr(cfg.ParameterNames));

            summary = [ ...
                table(state, sample, ...
                    'VariableNames', {'state', 'sample'}), ...
                parameterTable, ...
                table(valid, reason, peak, peakFrequency, unit, ...
                    meanAbsorption, outputFile, elapsed, ...
                    'VariableNames', {'valid', 'reason', 'peak_absorptance', ...
                    'peak_frequency', 'frequency_unit', 'mean_absorptance', ...
                    'output_file', 'elapsed_seconds'})];
        end

        function closeSession(obj)
            %CLOSESESSION Restore parameters and release COM handles once.
            if ~isempty(obj.Session)
                delete(obj.Session);
                obj.Session = [];
            end
        end
    end
end
