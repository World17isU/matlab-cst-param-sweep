classdef tConstraints < matlab.unittest.TestCase
    %TCONSTRAINTS Tests for the geometry constraint evaluator.

    methods (Test)
        function testValidRowPasses(testCase)
            cfg = cstsweep.Config();
            values = [6.0, 4.6, 3.4, 1.2, 2.8, 0.30];

            [ok, reason] = cstsweep.evaluateConstraints( ...
                values, cfg.ParameterNames, cfg.Constraints);

            testCase.verifyTrue(ok);
            testCase.verifyEqual(reason, "");
        end

        function testR2RuleIsReported(testCase)
            cfg = cstsweep.Config();
            values = [6.0, 3.0, 3.4, 1.2, 2.8, 0.30];

            [ok, reason] = cstsweep.evaluateConstraints( ...
                values, cfg.ParameterNames, cfg.Constraints);

            testCase.verifyFalse(ok);
            testCase.verifyEqual(reason, "R2<=R3");
        end

        function testR5RuleIsReported(testCase)
            cfg = cstsweep.Config();
            values = [6.0, 4.6, 3.4, 3.0, 2.8, 0.30];

            [ok, reason] = cstsweep.evaluateConstraints( ...
                values, cfg.ParameterNames, cfg.Constraints);

            testCase.verifyFalse(ok);
            testCase.verifyEqual(reason, "R5<=R6");
        end

        function testUnknownParameterIsReported(testCase)
            constraints = struct( ...
                "first", "RX", "second", "RY", ...
                "relation", "gt", "reason", "RX<=RY");

            testCase.verifyError( ...
                @() cstsweep.evaluateConstraints( ...
                    [1, 2], ["A", "B"], constraints), ...
                'cstsweep:Constraints:UnknownParameter');
        end

        function testEmptyConstraintsAlwaysPass(testCase)
            [ok, reason] = cstsweep.evaluateConstraints( ...
                [1, 2], ["A", "B"], struct([]));

            testCase.verifyTrue(ok);
            testCase.verifyEqual(reason, "");
        end
    end
end
