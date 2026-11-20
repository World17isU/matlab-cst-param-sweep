classdef tParamTable < matlab.unittest.TestCase
    %TPARAMTABLE Tests for CSV loading and validation.

    methods (Test)
        function testReadsNumericColumnsInRequestedOrder(testCase)
            file = testCase.writeFile("params.csv", [ ...
                "R1,R2,R3,R6,R5,T5"; ...
                "6.0,4.6,3.4,1.2,2.8,0.30"; ...
                "6.2,4.7,3.5,1.3,2.9,0.31"]);

            names = ["R1", "R2", "R3", "R6", "R5", "T5"];
            data = cstsweep.loadParameterTable(file, names);

            testCase.verifyEqual(data.numRows, 2);
            testCase.verifyEqual(data.names, names);
            testCase.verifyEqual(data.values(2, :), ...
                [6.2, 4.7, 3.5, 1.3, 2.9, 0.31], 'AbsTol', 1e-12);
        end

        function testMissingColumnIsReported(testCase)
            file = testCase.writeFile("params.csv", [ ...
                "R1,R2,R3,R6,R5,T5"; ...
                "6.0,4.6,3.4,1.2,2.8,0.30"]);

            testCase.verifyError( ...
                @() cstsweep.loadParameterTable(file, ...
                    ["R1", "R2", "R3", "R6", "R5", "T5", "R9"]), ...
                'cstsweep:ParamTable:MissingColumns');
        end

        function testNonNumericValueIsReported(testCase)
            file = testCase.writeFile("params.csv", [ ...
                "R1,R2,R3,R6,R5,T5"; ...
                "6.0,oops,3.4,1.2,2.8,0.30"]);

            testCase.verifyError( ...
                @() cstsweep.loadParameterTable(file, ...
                    ["R1", "R2", "R3", "R6", "R5", "T5"]), ...
                'cstsweep:ParamTable:NonNumericValues');
        end

        function testMissingFileIsReported(testCase)
            testCase.verifyError( ...
                @() cstsweep.loadParameterTable("does-not-exist.csv", ...
                    ["R1"]), ...
                'cstsweep:ParamTable:FileNotFound');
        end
    end

    methods (Access = private)
        function path = writeFile(obj, name, lines)
            fixture = obj.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            path = string(fullfile(fixture.Folder, name));
            fid = fopen(char(path), 'w');
            cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, '%s\n', cellstr(lines));
        end
    end
end
