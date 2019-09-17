classdef  haydon43K4U < linearstage
%% 
% haydon43K4U (all models) stage class
%
% All abstract methods should have doc text only in the abstract method class file.

properties
    positionUnits='mm'
end

methods
    
    %Constructor
    function obj = haydon43K4U(obj)
        obj.axisID = ''; % We have just one axis on the controller and run in "single mode"
    end %Constructor




end %methods


end