classdef C891 < genericPIcontroller
% C891 is a class that inherits linearcontroller and defines the interface between
% BakingTray and C-891 direct-drive motor controllers from PI using PI's GCS controller 
% class. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use the C891 controller, install the PI MATLAB support package and add it to your MATLAB path.
% You should find it in C:\Users\Public\PI\PI_MATLAB_Driver_GCS2
% Ensure that the instances of the class can be created and behave as expected. 
% e.g. that the .MOV method can be used to move the stage. So go through PI's example MATLAB scripts 
% and ensure all makes sense.
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
      paramMap
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

            %Build a map structure that allows us to read off desired controller parameters
            paramID = {'Position P Term', 'Position I Term', 'Position D Term', ...
                       'Velocity P Term', 'Velocity I Term', 'Velocity D Term'};

            IDhex = {'3000', '3001', '3002', ...
                    '3010', '3011', '3012'};

            obj.paramMap = containers.Map(paramID,IDhex);

        end % Constructor
    end

    methods
        function reportPIDparams(obj)
            % Prints to screen the PID parameters for this stage/controller pair
            theseKeys = obj.paramMap.keys;
            f = find( cellfun(@(x) endsWith(x,' Term'),theseKeys)  ) ; %Find keys associated with the the PID loop

            %Print the contents of these to screen
            for ii=1:length(f)
                thisKey = theseKeys{f(ii)};
                thisVal = obj.hC.qSPA('1', hex2dec(obj.paramMap(thisKey)) ); 
                fprintf('%s : %0.5f\n' , thisKey,  thisVal);
            end

        end
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


    methods
        function printAxisStatus(obj)
            printAxisStatus@genericPIcontroller(obj)

            enableDisableString={'disabled','enabled'};
            fprintf('Axis is %s\n', enableDisableString{obj.hC.qEAX('1')+1})
            fprintf('Servo is %s\n', enableDisableString{obj.hC.qSVO('1')+1})
            obj.reportPIDparams
            fprintf('%s\n',obj.hC.qIDN)

        end

        % The following have been tested with the V508 stages
        function success = referenceStage(obj)
          if obj.isStageReferenced
            success=true;
            return
          else
            %Disable servo and reference the stage
            obj.hC.SVO('1',false);
            obj.hC.FRF('1')
            obj.hC.SVO('1',true);
          end

        end

    end

end %close classdef 