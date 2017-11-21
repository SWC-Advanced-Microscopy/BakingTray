classdef C891 < linearcontroller
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
%   controllerID.interface='usb'
%   controllerID.ID='123456789012'  %The serial number of your controller
%   myC891 = C891(controllerID)
%
% It should also be possible to connect via RS232 or TCP/IP, but this isn't tested.
% See the doc text for the controllerID property in C891.m
%
%
%

    properties

    % controllerID - the information necessary to build a connected PI_GCS_Controller object
    %
    % This property is filled in if needed during C891.connect
    %
    % The C891 can be connected using USB, RS232, and TCPIP. In each case, controllerID
    % should be a structure that is defined as in the following examples. Note that only
    % USB has been tested so far:
    %
    % USB
    % controllerID.interface='usb'
    % controllerID.ID='123456789012'
    %
    % Serial
    % controllerID.interface='rs232'
    % controllerID.COM='COM1'
    % controllerID.baudrate=115200
    %
    % TCP/IP
    % controllerID.interface='tcpip'
    % controllerID.ip='xxx.xxx.xx.xxx'
    % controllerID.port='50000'

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

            if ~isempty(stageObject)
              obj.attachLinearStage(stageObject);
            end

            if ~isempty(logObject)
                obj.attachLogObject(logObject);
            end
        end % Constructor

        % Destructor
        function delete(obj)
            if ~isempty(obj.hC)
              obj.logMessage(inputname(1),dbstack,3,'Closing connection to C891 controller')
              obj.hC.CloseConnection
            end
        end % Destructor

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj,connectionDetails)

            if ~isstruct(connectionDetails)
              success=false;
              return
            end

            if ~isfield(connectionDetails,'interface')
              fprintf('No connectionDetails.interface field. Can not connect to C-891.\n')
              success = false;
              return
            end

          %Attempt to connect to the C-891 using the chosen interface
            try 
              PI_Controller = PI_GCS_Controller;
              switch lower(connectionDetails.interface)
                case 'usb'
                  fprintf('Attempting to connect to C-891 with serial number %s\n', connectionDetails.ID);
                  obj.hC = PI_Controller.ConnectUSB(connectionDetails.ID);
                case 'rs232'
                  fprintf('Attempting RS232 connection on port %s with baud rate %d\n',connectionDetails.COM, connectionDetails.baudrate);
                  obj.hC = PI_Controller.ConnectRS232(connectionDetails.COM, connectionDetails.baudrate);
                case 'tcpip'
                  fprintf('Attempting TCP/IP connection on ip %s port %s\n',connectionDetails.ip, connectionDetails.port);
                  obj.hC = PI_Controller.ConnectTCPIP(connectionDetails.ip, connectionDetails.port);
                otherwise
                  fprintf('Unknown connection interface %s. Failed to connect.\n',connectionDetails.interface);
                  success = false;
              end %switch

              obj.hC.InitializeController;

              catch
                fprintf('\n\n *** Failed to establish connection to PI C-891 controller.\n')
                fprintf(' *** Cycle the power on the unit and try again.  \n\n')
                success=false;
                rethrow(lasterror)
            end


            connected = obj.isControllerConnected;
            if ~connected
              fprintf('Failed to connect to controller\n')
              success=false;
              return
            end

          %Check that an axis is connected
            if isempty(obj.hC.qSAI_ALL)
              fprintf('No stages found on C-891 controller. FAILED TO CONNECT.\n')
              success=false;
              return
            end


          %Enable the stage
            enabled = obj.enableAxis;
            if ~enabled
              fprintf('Failed to enable axis on C-891\n')
              success=false;
              return
            end

        end %connect

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = isControllerConnected(obj)
            success=false;
            if isempty(obj.hC)
              obj.logMessage(inputname(1),dbstack,7,'No attempt to connect to the controller has been made')
              return
            end

            try 
              reply=obj.hC.qIDN;
              if ~isempty(strfind(reply,'C-891'))
                success=true;
              end
            catch
              obj.logMessage(inputname(1),dbstack,7,'Failed to communicate with C-891 controller')
            end
        end %isControllerConnected



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function moving = isMoving(obj,~)
            moving=obj.isAxisReady;
            if ~moving %unlikely to be moving if the stage isn't set up, so return false
              return
            end
            moving = obj.hC.IsMoving('1');
        end %isMoving



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = axisPosition(obj,~)
            ready=obj.isAxisReady;
            if ~ready
              pos=[];
              return
            end
            pos = obj.hC.qPOS('1');
            pos = obj.attachedStage.transformDistance(pos);
            obj.attachedStage.currentPosition=pos;
        end %axisPosition



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = relativeMove(obj, distanceToMove, ~)
          %TODO: abstract redundant code into linearcontroller.relativeMove
          %      C891.relative move will then call the abstract function that
          %      returns the transformed move distance (or the anon function to calculate this)
          %      C891 just needs to pass these to the API

          % <redundant>
            success=obj.isAxisReady;
            if ~success
              return
            end

            if ~obj.checkDistanceToMove(distanceToMove)
              return
            end


          %Check that it's OK to move here
            willMoveTo = distanceToMove+obj.axisPosition;
            if ~obj.isMoveInBounds(willMoveTo)
              success=false;
              return
            end
          % </redundant>

            obj.logMessage(inputname(1),dbstack,1,sprintf('moving by %0.f',distanceToMove));
            distanceToMove=obj.attachedStage.transformDistance(distanceToMove);
            success=obj.hC.MVR('1',distanceToMove);

        end %relativeMove



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = absoluteMove(obj, targetPosition, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            if ~obj.isMoveInBounds(targetPosition)
              success=false;
              return
            end

            obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));
            success=obj.hC.MOV('1',obj.attachedStage.transformDistance(targetPosition));
        end %absoluteMove


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = stopAxis(obj, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            success=obj.hC.StopAll;
        end %stopAxis


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = getPositionUnits(~,~)
              pos='mm'; %The units of the C-891 are fixed at mm and can't be queried       
        end %getPositionUnits

        function success=setPositionUnits(obj,controllerUnits,~)
          %The units of the C-891 are fixed at mm and can't be queried
            if ~strcmp(controllerUnits,'mm')
              obj.logMessage(inputname(1),dbstack,6,'C891 units work only in mm')
              success=false;
            end
            success=true;
        end %setPositionUnits


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function minPos=getMinPos(obj)
            minPos=getMinPos@linearcontroller(obj);

            if isempty(minPos)
              minPos = obj.hC.qTMN('1'); 
              minPos = st.transformDistance(minPos);
            end
        end

        function maxPos=getMaxPos(obj)
            maxPos=getMaxPos@linearcontroller(obj);

            if isempty(maxPos)
              maxPos = obj.hC.qTMX('1'); 
              maxPos = st.transformDistance(maxPos);
            end
        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % get or set speed and acceleration settings
        function velocity = getMaxVelocity(obj)
            ready=obj.isAxisReady;
            if ~ready
              velocity=[];
              return
            end
            velocity=obj.hC.qVEL('1');
        end

        function success = setMaxVelocity(obj, velocity)
            ready=obj.isAxisReady;
            success=false;
            if ~ready || ~isnumeric(velocity)
              return
            end

            success=obj.hC.VEL('1',velocity);
        end

        function velocity = getInitialVelocity(obj)
            velocity=0;
        end

        function success = setInitialVelocity(obj, velocity)
          %This can't be set
            success=false;
        end

        function accel = getAcceleration(obj)
            ready=obj.isAxisReady;
            if ~ready
              accel=[];
              return
            end
            accel=obj.hC.qACC('1');
        end

        function success = setAcceleration(obj, acceleration)
            success=obj.isAxisReady;
            if ~success
              return
            end
            if ~isnumeric(acceleration)
              success=false;
              return
            end
            success=obj.hC.ACC('1',acceleration);
        end


        function success=enableAxis(obj)
            success=obj.isAxisReady;
            if ~success
              return
            end

            EAX = obj.hC.EAX('1',1); %enable the axis
            SVO = obj.hC.SVO('1',1); %enable the servo
            success = EAX * SVO;

            if ~success
              obj.logMessage(inputname(1),dbstack,5,'Failed to commincate with the C891 controller to enable axis')
              return
            end

          %Check the enable state
            if obj.hC.qEAX('1')==0
              obj.logMessage(inputname(1),dbstack,5,'C891 motor enable state remains off')
              success=false;
              return
            end

          %Check the servo state
            if obj.hC.qSVO('1')==0
              obj.logMessage(inputname(1),dbstack,5,'C891 servo state remains off')
              success=false;
              return
            end

        end %enableAxis


        function success=disableAxis(obj)
            success=obj.isAxisReady;
            if ~success
              return
            end

            SVO = obj.hC.SVO('1',0); %disable the servo
            EAX = obj.hC.EAX('1',0); %disable the axis
            success = EAX * SVO;

            if ~success
              obj.logMessage(inputname(1),dbstack,5,'Failed to commincate with the C891 controller to disable axis')
              return
            end

          %Check the enable state
            if obj.hC.qEAX('1')==1
              obj.logMessage(inputname(1),dbstack,5,'C891 motor enable state remains on')
              success=false;
              return
            end

          %Check the servo state
            if obj.hC.qSVO('1')==1
              obj.logMessage(inputname(1),dbstack,5,'C891 servo state remains on')
              success=false;
              return
            end

        end %disableAxis

    end %close methods


    methods (Hidden) % Hidden methods specific to C891
        function enableInMotionTrigger(obj,DIOline)
            % Enables "in motion" DIO on defined trigger line
            obj.hC.TRO(DIOline,0)
            obj.hC.CTO(DIOline,2,1)
            obj.hC.CTO(DIOline,3,6)
            obj.hC.TRO(DIOline,1)
        end %enableMotionInMotionTrigger(obj,DIOline)

        function disableInMotionTrigger(obj,DIOline)
            % Disabled "in motion" DIO on defined trigger line
            obj.hC.TRO(DIOline,0) %disable trigger
            obj.hC.CTO(DIOline,3,0) %Revert to default
        end %enableMotionInMotionTrigger(obj,DIOline)

    end %close hidden methods


end %close classdef 