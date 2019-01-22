function PI = PI_Build_Example_C863
	% function PI = PI_Build_Example
	%
	% This function shows an example of how to connect to a PI C-891 for testing. 
	% If you are having trouble connecting to a device, you should make a copy 
	% of this file in a different location then edit and run it. 
	%
	% BE CAUTIOUS RUNNING THIS FILE! Ensure your stage can't hit anything, as there
	% the soft-limits for motions used in this function are very large. Remove
	% water bath and lower Z-stage before proceeding. 
	%
	% See comments within the file for more info.
	%
	% Inputs
	% None, but you will need to edit below. 
	%
	%
	% Rob Campbell - SWC 2019
	%
	% See also: buildMotionComponent, genericPIcontroller, and linearcontroller

	% First we will set up a stage
    stageComponent=genericPIstage;
    stageComponent.axisName='xAxis'; %Doesn't matter what it's called for now
    stageComponent.minPos=10;
    stageComponent.maxPos=300;

    % Make a PI controller object with this stage attached
    PI = C863(stageComponent); % <-- EDIT FOR OTHER CONTROLLERS

	% Now we must tell the controller where to connect to

	PImodel='C-863'; % <---- EDIT FOR OTHER CONTROLLERS
	% Option one: these are the setting for connecting via USB
    controllerIDusb.interface='usb';
    controllerIDusb.controllerModel=PImodel;
    controllerIDussb.ID='1122342334';

    % Option two: these are the settings for connecting via serial
    controllerIDrs232.interface='rs232';
    controllerIDrs232.controllerModel=PImodel;
    controllerIDrs232.COM=10;
    controllerIDrs232.baudrate=115200;

    PI.connect(controllerIDrs232); %Connect to the controller

    % It should at this point say it's connected. It might say it failed. 
    % If it failed, it's possible it's actually connected but that something
    % silly went wrong. The following code confirms using low-level commands:

    fprintf('\nqIDN returns:\n')
    disp(PI.hC.qIDN) % Should print to screen the controller version number if connected

    fprintf('\nqPOS returns:\n')
	disp(PI.hC.qPOS('1')) % Should print the axis position if connected

	% If the above fail also, then you really aren't connected. Check your ID number and check if
	% another piece of software is already talking to the device. 
	% If the above works, then we likely have a bug in the PI stage class or you're using a slightly 
	% different controller to the one it expects. Send an issue report but also try to debug yourself.


