classdef C891 < genericPIcontroller
% C891 is a class that inherits linearcontroller and defines the interface between
% BakingTray and PI's GCS controller class. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use the C891 stage, install the PI MATLAB support package. Ensure that the instances of
% the class can be created and behave as expected. e.g. that the .MOV method can be used to
% move the stage. So go through PI's example MATLAB scripts and ensure all makes sense.
%
% To use this class you need to supply the method of connection and the ID for the connection.
%
% e.g.
% 
% >> STAGE = genericPIstage;
% >> STAGE.axisName='someName'; %Does not matter for this toy example
% >> PIC891 = C891(STAGE); %Create  control class
% >> controllerID.interface='usb'; %We will connect via USB...
% >> controllerID.ID= '116010269'; %Using the serial number of the C891
% >> controllerID.controllerModel='C-891';
% Now we are ready to communicate with the device and connect to it:
%
% >> PIC891.connect(controllerID)
% Loading PI_MATLAB_Driver_GCS2 ...
% PI_MATLAB_Driver_GCS2 loaded successfully.
% Attempting to connect to C-891 with serial number 116010269


% It should also be possible to connect via RS232 or TCP/IP, but this isn't tested.
% See the doc text for the controllerID property in C891.m
%
%
%

    properties

      % See also genericPIcontroller

    end % close public properties


    methods
        % Constructor
        function obj=C891(stageObject,logObject)
            if nargin<1
              stageObject=[];
            end
            if nargin<2
                logObject=[];
            end
            obj = obj@genericPIcontroller(stageObject,logObject);
        end % Constructor
    end


    methods (Hidden) % Hidden methods specific to C891
        function enableInMotionTrigger(obj,DIOline1,DIOline2)
            % Enables "in motion" DIO on defined trigger line (p. 102, MS205E v.2.0.0)
            obj.hC.TRO(DIOline1,0)
            obj.hC.CTO(DIOline1,2,1)
            obj.hC.CTO(DIOline1,3,6)
            obj.hC.TRO(DIOline1,1)

            %If a second input is provided, set up "Position distance" trigger mode (p. 99, MS205E v.2.0.0)
            if nargin>2
              obj.hC.TRO(DIOline2,0)
              obj.hC.CTO(DIOline2,2,1)

              obj.hC.CTO(DIOline2,3,0)
              obj.hC.CTO(DIOline2,1,0.547)

              obj.hC.TRO(DIOline2,1)
            end

        end %enableMotionInMotionTrigger(obj,DIOline)

        function motionTrigMax(obj,DIOline,pos)
            % Sets up a max position for triggering
            obj.hC.TRO(DIOline,0)
            obj.hC.CTO(DIOline,8,pos)
            obj.hC.TRO(DIOline,1)
        end

        function motionTrigMin(obj,DIOline,pos)
            % Sets up a min position for triggering
        end

    end %close hidden methods


end %close classdef 