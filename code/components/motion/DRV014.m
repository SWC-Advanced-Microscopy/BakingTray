classdef DRV014 < linearstage
%% 
% DRV014 (all models) stage class
%
% All abstract methods should have doc text only in the abstract method class file.

properties
    %TODO: go through these -- are they all needed?
    positionUnits
    
    %Referencing variables. Fill these in for defining how the actuator
    %will be referenced. Here we set the limit switches and homing direction 
    %so that the retracted position will be the zero position. We assume the 
    %device will be used as the Z jack and so the safest way to set it up
    %is with zero being that the stage is lowered.
    limitSwitch=4 %which limit switch will be the reference switch for zero
    homingDir=1   %which direction to travel for setting the reference?

    %The velocity and offset for reaching the zero position
    homeVel=1.5;
    zeroOffset=0.5;
    
    %Invert the positions so that more positive numbers mean that the actuator 
    %are more extended. 
    % TODO this is a legacy property. Ignore it. 
    transformDistance = @(x) -1*x;
end

methods
    
    %Constructor
    function obj = DRV014(obj)
        obj.axisID = 0; %Always zero for BSC201, so with this controller we don't even use this
    end %Constructor


end %methods


end