classdef tDryRun < matlab.unittest.TestCase
    %TDRYRUN Integration test for the no-CST planning path.

    methods (Test)
        function testPlanIsWrittenForEveryState(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            folder = string(fixture.Folder);
            csv = fullfile(folder, "params.csv");
            fid = fopen(char(csv), 'w');
            fprintf(fid, 'R1,R2,R3,R6,R5,T5\n');
            fprintf(fid, '6.0,4.6,3.4,1.2,2.8,0.30\n');
            fprintf(fid, '6.1,3.0,3.4,1.2,2.8,0.30\n');
            fclose(fid);

            cfg = cstsweep.Config();
            cfg.CsvPath = csv;
            cfg.OutputDir = fullfile(folder, "out");
            cfg.SamplesPerState = 2;
            cfg.TestMode = false;
            cfg.DryRun = true;
            cfg.Verbose = false;

            summary = cstsweep.SweepRunner(cfg).run();

            testCase.verifyEqual(height(summary), 4);
            testCase.verifyEqual(nnz(summary.eligible), 2);
            testCase.verifyTrue(isfile( ...
                fullfile(cfg.OutputDir, "planned_samples.csv")));
            testCase.verifyTrue(isfile( ...
                fullfile(cfg.OutputDir, "sweep.log")));
        end
    end
end
