classdef (Abstract) linearstage < handle
%%  linearstage
%
% The linearstage abstract class is a software entity that represents the physical
% linear stage, linear actuator, or PIFOC connected to a hardware controller.
%
% The linearstage abstract class declares methods and properties that are used by the
% BakingTray class to move linear actuators, linear stages, PIFOCs, etc. linearstage
% does little by itself. It is "attached" to an object that inherits linearcontroller
% using linearcontroller.attachLinearStage. This method adds an instance of a class
% that inherits linearstage to the linearcontroller.attachedStage property.
%
% Classes that inherit linearstage serve as a representation of the stage in software.
% They store properties that allow the controller to address them, that define which
% axis they represent within the hardware system, and any other relevant properties,
% such as minimum and maximum allowed positions of the stage.
%
% NOTE!
% When setting up your system, always ensure that it is not possible for hardware to
% move to a position that might cause damage. Use the minPos and maxPos properties
% of linearstage to define soft limits that methods moving the stage will respect.
% Use a safe environment to ensure these are respected before deploying any new classes
% or significant changes to the code. You might also want to set up limit switches or,
% better yet, position the hardware such that it is not possible for collisions to
% occur.
%
% Rob Campbell - Basel 2016


    properties

        axisID
        % This is a very important property for some controllers and stages. e.g. for
        % PI stages it is the property used by the hardware controller (i.e. the class that
        % inherits linearcontroller) to identify the stage axis and send commands to it.
        % Thus, the value of axisID must be compatible with the controller and you should
        % expect it it to be sent to the controller unmodified. With controllers that
        % can have only one stage attaged, e.g. a C891 with a PI V-551 stage, the axisID property
        % is defined in the V551 class. In that case it will always be the string '1', because
        % this is what the C-891 controller expects. In cases where there are multiple axes per
        % controller, you should define the axisID property for each manually when you build the
        % objects. see buildConnectedControllers.m

        positionUnits
        % This property stores the units the stage works in. Not all controllers use this.


        invertDistance = 1
        % If -1, motion target positions are inverted. If 1 they are not inverted.
        % This is done to ensure that positive X motions are rightwards, positive Y motions are
        % away, and positive z-motions are upwards.

        positionOffset = 0
        % This property may be changed to ensure that the mid-point of X and Y motions is
        % the middle of the stage. This isn't critical, but it's more intuitive for the user.
        % Also to ensure that the fully retracted Z axis is zero.

        controllerUnitsInMM = 1
        % If the motion controller expects inputs in, say, number of stepper motor steps then
        % we need to convert this to mm. So if there are 10,000 steps in a mm this value will
        % be 1/10000.


        axisName
        % This string defines the name (role) of the axis within BakingTray.
        % The BakingTray object expects it to be one of the following
        % strings:
        % 'xAxis' - the stage that moves the sample along the X dimension.
        %           the X stage axis is that which moves the sample towards or away from the vibratome
        % 'yAxis' - the stage that moves the sample along the Y dimension.
        %           the Y stage axis is that which moves the sample towards or away from the user.
        % 'zAxis' - the actuator that jacks the X/Y stages up and down.
        % 'fastZ' - the fast focuser axis (e.g. a PIFOC) (NOT SUPPORTED RIGHT NOW)
        % 'slowZ' - slow objective focus (NOT SUPPORTED RIGHT NOW)


        % The maximum and minimum allowable positions of the stage in mm.
        % If missing, then linearcontroller will attempt to fill these in
        % using linearcontroller.attachLinearStage. ** NOTE: you are responsible for
        % ensuring your hardware does not cause damage. **
        minPos
        maxPos

    end %close properties

    % These are GUI-related properties. The view class that comprises the GUI listens to changes in these
    % properties to know when to update the GUI. It is therefore necessary for these to be updated as
    % appropriate by classes which inherit linearstage or interact with linearstage. e.g. when the stage is
    % moved, the stage position should read and the position property updated. Failing to do this will
    % cause the GUI to fail to update.
    properties (Hidden, SetObservable)
        currentPosition  % The current (transformed) position of the stage in mm. This is set by the
                         % linearcontroller axisPosition method. It is read by other classes and so must
                         % be in the correct units and sign for display. i.e. axisPosition should do
                         % something like:
                         % POS = obj.hC.getPosition;
                         % POS = obj.attachedStage.transformdDstance(POS);
                         % obj.attachedStage.currentPosition=POS;
    end %close GUI-related properties


    % All abstract methods must be defined by the child class that inherits this abstract class
    % You should also define a suitable destructor to clean up after you class
    methods (Abstract) %All methods in this block are considered critical and you should define them
    end



end %close classdef
