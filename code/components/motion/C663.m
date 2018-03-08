classdef C663 < genericPIcontroller
% C663 is a class that inherits linearcontroller and defines the interface between
% BakingTray and PI's GCS controller class. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use the C663 stage, install the PI MATLAB support package. Ensure that the instances of
% the class can be created and behave as expected. e.g. that the .MOV method can be used to
% move the stage. So go through PI's example MATLAB scripts and ensure all makes sense.
%
% To use this class you need to supply the method of connection and the ID for the connection.
%
% e.g.
% 
% >> STAGE = genericPIstage;
% >> STAGE.axisName='someName'; %Does not matter for this toy example
% >> PIC663 = C663(STAGE); %Create  control class
% >> controllerID.interface='usb'; %We will connect via USB...
% >> controllerID.ID= '116010269'; %Using the serial number of the C663
% >> controllerID.controllerModel='C-663';
% Now we are ready to communicate with the device and connect to it:
%
% >> PIC663.connect(controllerID)
% Loading PI_MATLAB_Driver_GCS2 ...
% PI_MATLAB_Driver_GCS2 loaded successfully.
% Attempting to connect to C-C663 with serial number 116010269


% It should also be possible to connect via RS232 or TCP/IP, but this isn't tested.
% See the doc text for the controllerID property in C663.m
%
%
%

    properties

      % See also genericPIcontroller

    end % close public properties


    methods
        % Constructor
        function obj=C663(stageObject,logObject)
            if nargin<1
              stageObject=[];
            end
            if nargin<2
                logObject=[];
            end
            obj = obj@genericPIcontroller(stageObject,logObject);
        end % Constructor


        %There is no enable and disable with this controller
        function success=enableAxis(obj)
          success=true;
        end

        function success=disableAxis(obj)
          success=true;
        end


    end %close 


end %close classdef 