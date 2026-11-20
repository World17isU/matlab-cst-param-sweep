classdef tSParams < matlab.unittest.TestCase
    %TSPARAMS Tests for the ASCII S-parameter parser and absorptance maths.

    methods (Test)
        function testDbValuesBecomeLinearMagnitude(testCase)
            file = testCase.writeFile("db.txt", [ ...
                "% CST Studio Suite ASCII export"; ...
                "Frequency / THz   SZmax(1),Zmax(1)"; ...
                "1.0  -10"; ...
                "2.0  -20"]);

            data = cstsweep.readSParameters(file, "db");

            testCase.verifyEqual(data.frequency, [1; 2], 'AbsTol', 1e-12);
            testCase.verifyEqual(data.magnitude, ...
                [10^-0.5; 0.1], 'AbsTol', 1e-12);
            testCase.verifyEqual(data.format, "db");
            testCase.verifyEqual(data.unit, "THz");
        end

        function testAutoDetectsLinearMagnitude(testCase)
            file = testCase.writeFile("linear.txt", [ ...
                "# comma-separated export"; ...
                "1.0,0.1"; ...
                "2.0,0.2"; ...
                "3.0,0.3"]);

            data = cstsweep.readSParameters(file, "auto");

            testCase.verifyEqual(data.format, "linear");
            testCase.verifyEqual(data.magnitude, [0.1; 0.2; 0.3], ...
                'AbsTol', 1e-12);
        end

        function testAutoDetectsDbMagnitude(testCase)
            file = testCase.writeFile("auto-db.txt", [ ...
                "1.0  -12.5"; ...
                "2.0  -18.0"]);

            data = cstsweep.readSParameters(file, "auto");

            testCase.verifyEqual(data.format, "db");
            testCase.verifyEqual(data.magnitude(1), 10^(-12.5 / 20), ...
                'AbsTol', 1e-12);
        end

        function testFrequencyIsSorted(testCase)
            file = testCase.writeFile("unsorted.txt", [ ...
                "2.0  0.2"; ...
                "1.0  0.1"]);

            data = cstsweep.readSParameters(file, "auto");

            testCase.verifyEqual(data.frequency, [1; 2]);
            testCase.verifyEqual(data.magnitude, [0.1; 0.2], 'AbsTol', 1e-12);
        end

        function testCommentOnlyFileIsRejected(testCase)
            file = testCase.writeFile("empty.txt", ["# no data here"]);

            testCase.verifyError( ...
                @() cstsweep.readSParameters(file, "auto"), ...
                'cstsweep:SParams:NoData');
        end

        function testAbsorptionFromMagnitude(testCase)
            result = cstsweep.computeAbsorption([1; 2; 3], [0.5; 0; 1]);

            testCase.verifyEqual(result.absorption, [0.75; 1; 0], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(result.peakAbsorption, 1);
            testCase.verifyEqual(result.peakFrequency, 2);
            testCase.verifyEqual(result.meanAbsorption, mean([0.75; 1; 0]), ...
                'AbsTol', 1e-12);
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
