function Z = Zaber_Build_Example(comport)
	% function Z = Zaber_Build_Example(comport)
	%
	% This function shows an example of how to connect to a Zaber stage for testing.
	% If you are having trouble connecting to a device, you can use the file to
    % explore what is wrong. If necessary, make a copy of this file in a different
    % location then edit and run it. Do not edit in situ as this will block a git pull.
	%
	% BE CAUTIOUS RUNNING THIS FILE! Ensure your stage can't hit anything, as there
	% the soft-limits for motions used in this function are very large. Remove
	% water bath and lower Z-stage before proceeding.
	%
	% See comments within the file for more info.
	%
	% Inputs
	% comport - string defining the com port to connect to. e.g. 'com3'
	%
    % Example
    % Z = Zaber_Build_Example('com4')
    % Z.absoluteMove(5)
    % Z.axisPosition
    % delete(PI)
	%
	%
	% Using a rotary controller
	% The encoder wheel has a button that, when long-pressed, will switch between
	% position and speed modes. This can be avoided (keeping it position mode)
	% by running the following commands in Zaber Launcher:
	%
	% /1 trigger 1 when 1 knob.mode == 0
	% /1 trigger 1 action a 1 knob.mode = 1
	% /1 trigger 1 enable
	%
	% This assumes your controller is set to device 1, so if not, just replace the first
	% 1 in each command with the actual device number.
	%
	%
	% Rob Campbell - SWC 2023
	%
	% See also: buildMotionComponent, genericPIcontroller, and linearcontroller

    if nargin<1 || isempty(comport) || ~ischar(comport)
        help(mfilename)
        return
    end

	% First we will set up a stage
    stageComponent=genericPIstage;
    stageComponent.axisName='xAxis'; %Doesn't matter what it's called for now
    stageComponent.minPos = -70; %May need editing
    stageComponent.maxPos = 70; %May need editing

    % Make a Zaber controller object with this stage attached
    Z = genericZaberController(stageComponent);
    Z.connect(comport);



    % It should at this point say it's connected. It might say it failed.
    % If it failed, it's possible it's actually connected but that something
    % silly went wrong. The following code confirms using low-level commands:

