classdef DRV014 < linearstage
%% 
% DRV014 (all models) stage class
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

end

methods
    
    %Constructor
    function obj = DRV014(obj)
        obj.axisID = 0; %Always zero for BSC201, so with this controller we don't even use this
    end %Constructor


end %methods


end