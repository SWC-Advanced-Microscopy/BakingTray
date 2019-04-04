classdef  haydon43K4U < linearstage
%% 
% haydon43K4U (all models) stage class
%
% All abstract methods should have doc text only in the abstract method class file.

properties
    positionUnits='mm'


    % The scale factor is the microns per step. The following value is a 
    % default. If your system needs a different value then you should alter 
    % it when you connect to the device. Do not modify the code. 
    scaleFactor = 1.5305E-04 %mm  per command "tick"
end

methods
    
    %Constructor
    function obj = haydon43K4U(obj)
        obj.axisID = ''; % We have just one axis on the controller and run in "single mode"

        obj.transformInputDistance = @(x) x/obj.scaleFactor; %mm to ticks
        obj.transformOutputDistance = @(x) x*obj.scaleFactor; %ticks to mm
    end %Constructor




end %methods


end