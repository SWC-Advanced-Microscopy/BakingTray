classdef C863 < genericPIcontroller
% C863 is a class that inherits linearcontroller and defines the interface between
% BakingTray and C-863 stepper motor controllers from PI using PI's GCS controller 
% class. In effect, this is a glue class.
%
% C863 is a class that inherits linearcontroller and defines the interface between
% BakingTray and PI's GCS controller class. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use the C863 controller, install the PI MATLAB support package. Ensure that the instances of
% the class can be created and behave as expected. e.g. that the .MOV method can be used to
% move the stage. So go through PI's example MATLAB scripts and ensure all makes sense.
%
% To use this class you need to supply the method of connection and the ID for the connection.
%
% e.g.
% 
% %% Make a stage and attach it to the controller object
% >> STAGE = genericPIstage;
% >> STAGE.axisName='someName'; %Does not matter for this toy example
% >> PIC863 = C863(STAGE); %Create  control class
%
% %% EITHER connect to the controller using USB with the controller serial number 
% >> controllerID.interface='usb'; %We will connect via USB...
% >> controllerID.ID= '116010269'; %Using the serial number of the C863
% >> controllerID.controllerModel='C-863';
% Now we are ready to communicate with the device and connect to it:
%
% >> PIC863.connect(controllerID)
% Loading PI_MATLAB_Driver_GCS2 ...
% PI_MATLAB_Driver_GCS2 loaded successfully.
% Attempting to connect to C-C863 with serial number 116010269
%
%
% %% OR connect using RS232 by supplying a COM port ID
% >> controllerID.interface='rs232'; % Connect via RS232
% >> controllerID.COM= 20; % At port COM20
% >> controllerID.baudrate= 115200; % At this baudrate
% >> controllerID.controllerModel='C-863';
% >> PIC863.connect(controllerID)

    properties

      % See also genericPIcontroller

    end % close public properties


    methods
        % Constructor
        function obj=C863(stageObject,logObject)
            if nargin<1
              stageObject=[];
            end
            if nargin<2
                logObject=[];
            end

            obj = obj@genericPIcontroller(stageObject,logObject);
        end % Constructor

        % TODO: for now we don't query the controller as it's far too slow
        function success = isControllerConnected(obj)
            success = false;
            if isempty(obj.hC)
              fprintf('The controller property "hC" is empty.\n')
              obj.logMessage(inputname(1),dbstack,7,'No attempt to connect to the controller has been made')
              return
            end
            success=true;
        end %isControllerConnected

        function success = referenceStage(obj)

          if obj.isStageReferenced
            fprintf('Stage already referenced\n')
            success=true;
            return
          else
            %Reference the stage
            obj.hC.FRF('1')
            obj.axisPosition; %update the position in the stage class
          end
        end
    end %close 


end %close classdef 