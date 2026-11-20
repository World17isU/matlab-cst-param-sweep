function [ok, reason] = evaluateConstraints(values, names, constraints)
%EVALUATECONSTRAINTS Check one parameter row against geometry rules.
%
%   [ok, reason] = cstsweep.evaluateConstraints(values, names, constraints)
%   returns true when every rule holds. On the first violation, ok is false
%   and reason is the rule's human-readable reason (or a generated one).
%
%   Constraints is a struct array with fields first, second, relation, and
%   reason. relation is one of "gt", "ge", "lt", or "le".
%
%   See also cstsweep.Config, cstsweep.SweepRunner.

arguments
    values (1,:) double
    names (1,:) string
    constraints struct
end

ok = true;
reason = "";

if isempty(constraints)
    return
end

for k = 1:numel(constraints)
    constraint = constraints(k);
    first = string(constraint.first);
    second = string(constraint.second);

    a = values(strcmp(names, first));
    b = values(strcmp(names, second));
    if isempty(a) || isempty(b)
        error('cstsweep:Constraints:UnknownParameter', ...
            'Constraint refers to parameters not in ParameterNames: %s, %s.', ...
            first, second);
    end

    relation = string(constraint.relation);
    switch relation
        case "gt"
            pass = a > b;
        case "ge"
            pass = a >= b;
        case "lt"
            pass = a < b;
        case "le"
            pass = a <= b;
        otherwise
            error('cstsweep:Constraints:InvalidRelation', ...
                'Invalid constraint relation "%s".', relation);
    end

    if ~pass
        ok = false;
        reason = string(constraint.reason);
        if strlength(reason) == 0
            reason = sprintf('%s %s %s', first, relation, second);
        end
        return
    end
end
end
