classdef  haydon43K4U < linearstage
%% 
% haydon43K4U (all models) stage class
%
% All abstract methods should have doc text only in the abstract method class file.

properties
    %TODO: go through these -- are they all needed?
    positionUnits

    %Referencing variables. Fill these in for defining how the actuator
    %will be referenced
    %other than the default for any one of them
    limitSwitch %which limit switch will be the reference switch for zero
    homingDir %which direction to travel for setting the reference?
    %The velocity and offset for reaching the zero position
    homeVel
    zeroOffset

    % The scale factor is the microns per step. The following value is a 
    % default. If your system needs a different value then you should alter 
    % it when you connect to the device. Do not modify the code. 
    scaleFactor = 1.5305E-04 %mm  per command "tick"
end

methods
    
    %Constructor
    function obj = haydon43K4U(obj)
        obj.axisID = 'A'; % We have just one axis on the controller

        obj.transformInputDistance = @(x) x/obj.scaleFactor; %mm to ticks
        obj.transformOutputDistance = @(x) x*obj.scaleFactor; %ticks to mm
    end %Constructor




end %methods


end