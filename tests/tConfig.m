classdef tConfig < matlab.unittest.TestCase
    %TCONFIG Tests for configuration validation.

    methods (Test)
        function testDefaultStates(testCase)
            cfg = cstsweep.Config();

            testCase.verifyNumElements(cfg.States, 2);
            testCase.verifyEqual([cfg.States.value], [80000, 150]);
            testCase.verifyEqual(string({cfg.States.prefix}), ["K", "F"]);
        end

        function testValidConfigurationPasses(testCase)
            cfg = cstsweep.Config();
            cfg.CsvPath = testCase.writeCsv();
            cfg.OutputDir = "results/test";

            testCase.verifyClass(cfg.validate(), 'cstsweep.Config');
        end

        function testDuplicateStatePrefixIsRejected(testCase)
            cfg = cstsweep.Config();
            cfg.CsvPath = testCase.writeCsv();
            cfg.States(2).prefix = cfg.States(1).prefix;

            testCase.verifyError(@() cfg.validate(), 'cstsweep:Config:Invalid');
        end

        function testStateParameterMustNotBeASweepParameter(testCase)
            cfg = cstsweep.Config();
            cfg.CsvPath = testCase.writeCsv();
            cfg.ParameterNames = ["S", "R1"];

            testCase.verifyError(@() cfg.validate(), 'cstsweep:Config:Invalid');
        end

        function testUnknownConstructorOptionIsRejected(testCase)
            testCase.verifyError( ...
                @() cstsweep.Config('NoSuchOption', 1), ...
                'cstsweep:Config:UnknownOption');
        end

        function testInvalidFormatIsRejected(testCase)
            thrown = false;
            try
                cstsweep.Config('SParameterFormat', "dB");
            catch
                thrown = true;
            end
            testCase.verifyTrue(thrown);
        end

        function testMissingCsvIsRejected(testCase)
            cfg = cstsweep.Config();
            cfg.CsvPath = "does-not-exist.csv";

            testCase.verifyError(@() cfg.validate(), 'cstsweep:Config:Invalid');
        end
    end

    methods (Access = private)
        function path = writeCsv(obj)
            fixture = obj.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            path = string(fullfile(fixture.Folder, "params.csv"));
            fid = fopen(char(path), 'w');
            cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, 'R1,R2,R3,R6,R5,T5\n');
            fprintf(fid, '6.0,4.6,3.4,1.2,2.8,0.30\n');
        end
    end
end
