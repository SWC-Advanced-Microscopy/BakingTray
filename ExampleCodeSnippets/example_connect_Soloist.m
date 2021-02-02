function SOLO = example_connect_Soloist
% Example function showing how to connect to an AeroTech SoloistMP
%
% function SOLO = example_connect_Soloist
%
% Instructions
% Edit the controller ID to match yours then:
% SOLO = example_connect_Soloist;
% SOLO.absoluteMove(10)
% SOLO.axisPosition
% etc: methods(SOLO)
% You should have control over the device now
%
% delete(SOLO) %Closes the connection
% 
% See also: buildMotionComponent, linearcontroller

STAGE = generic_AeroTechZJack;
STAGE.axisName='someName';
STAGE.maxPos = 35; % You may need to edit this
SOLO = soloist(STAGE);

controllerID.interface='ethernet';
controllerID.ID= '618277-1-1'; % <--- EDIT THIS WITH YOUR UNIT'S ID

SOLO.connect(controllerID)
