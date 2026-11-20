function results = run_tests()
%RUN_TESTS Run the matlab.unittest suite for this package.
%
%   results = run_tests() discovers every test class under tests/, runs it,
%   and returns the matlab.unittest.TestResult array.
%
%   See also matlab.unittest.TestSuite.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, "src"));
addpath(fullfile(root, "tests"));

import matlab.unittest.TestSuite
import matlab.unittest.TestRunner

suite = TestSuite.fromFolder(char(fullfile(root, "tests")));
runner = TestRunner.withTextOutput('Verbosity', 3);
results = runner.run(suite);
end
