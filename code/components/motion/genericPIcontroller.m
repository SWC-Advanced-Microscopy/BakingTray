classdef genericPIcontroller < linearcontroller
% genericPIcontroller is a class that inherits linearcontroller and defines the interface between
% BakingTray and PI's GCS controller class. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use genericPIcontroller, install the PI MATLAB support package. Ensure that the instances of
% the class can be created and behave as expected. e.g. that the .MOV method can be used to
% move the stage. So go through PI's example MATLAB scripts and ensure all makes sense.
%
% Do not use this class directly! Instead, write a sub-class specific to the device you are controlling. 
% e.g. see C891.m and C663.m

    properties
      % The following are inherited properties from linearcontroller
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
        function obj=genericPIcontroller(stageObject,logObject)

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
              fprintf('Closing connection to %s controller\n',obj.controllerID.controllerModel);
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
            fprintf('No connectionDetails.interface field. Can not connect to %s.\n', connectionDetails.controllerModel)
            success = false;
            return
          end

          % Ensure the controller we are connecting is one that is supported. More controllers likely will work, but 
          % to keep safe we hard code the names of the tested ones here and report if it's not one of them.
          % Names must be in the form returned by obj.hC.qIDN (see obj.isControllerConnected)
          knownWorkingControllers = {'C-891', 'C-663'}; 
          switch connectionDetails.controllerModel
            case knownWorkingControllers
              % pass
            otherwise
              % We haven't tested this controller or there is a typo
              fprintf('Controller %s is untested. Proceed with caution!', connectionDetails.controllerModel)
          end


          %Attempt to connect to the PI controller using the chosen interface
          % TODO -- this is taken from the C891 class and hopefully it will work for others too, but not sure. 
          % Seems to work for C-663. 
          try
            PI_Controller = PI_GCS_Controller;
            switch lower(connectionDetails.interface)
              case 'usb'
                fprintf('Attempting to connect to %s with serial number %s\n', connectionDetails.controllerModel, connectionDetails.ID);
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

            obj.controllerID = connectionDetails;
            obj.hC.InitializeController;

            catch
              fprintf('\n\n *** Failed to establish connection to PI %s controller.\n', connectionDetails.controllerModel)
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
            fprintf('No stages found on %s controller. FAILED TO CONNECT.\n',  obj.controllerID.controllerModel)
            success=false;
            return
          end


          %Enable the stage
          enabled = obj.enableAxis;
          if ~enabled
            fprintf('Failed to enable axis on %s\n', obj.controllerID.controllerModel)
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
              reply=obj.hC.qIDN; %Contains a string bearing the name of the controller (e.g. C-891)
              if ~isempty(strfind(reply, obj.controllerID.controllerModel))
                success=true;
              end
            catch
              obj.logMessage(inputname(1),dbstack,7,'Failed to communicate with %s controller', obj.controllerID.controllerModel)
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
          %      genericPIcontroller.relative move will then call the abstract function that
          %      returns the transformed move distance (or the anon function to calculate this)
          %      genericPIcontroller just needs to pass these to the API

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
              pos='mm'; %The units of the C-891 are fixed at mm and can't be queried %TODO -- is this the case for all PI controllers?
        end %getPositionUnits

        function success=setPositionUnits(obj,controllerUnits,~)
          %The units of the C-891 are fixed at mm and can't be queried %TODO -- is this the case for all PI controllers?
            if ~strcmp(controllerUnits,'mm')
              obj.logMessage(inputname(1),dbstack,6,'C-891 units work only in mm') % TODO!
              success=false;
            end
            success=true;
        end %setPositionUnits


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function minPos=getMinPos(obj)
            minPos=getMinPos@linearcontroller(obj);

            if isempty(minPos)
              minPos = obj.hC.qTMN('1'); 
              minPos = obj.attachedStage.transformDistance(minPos);
            end
        end

        function maxPos=getMaxPos(obj)
            maxPos=getMaxPos@linearcontroller(obj);

            if isempty(maxPos)
              maxPos = obj.hC.qTMX('1'); 
              maxPos = obj.attachedStage.transformDistance(maxPos);
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
              msg = sprintf('Failed to communicate with the %s controller to enable axis', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              return
            end

            %Check the enable state
            if obj.hC.qEAX('1')==0
              msg = sprintf('%s motor enable state remains off', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success=false;
              return
            end

            %Check the servo state
            if obj.hC.qSVO('1')==0
              msg = sprintf('%s servo state remains off', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
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
              msg = sprintf('Failed to communicate with the %s controller to disable axis', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              return
            end

            %Check the enable state
            if obj.hC.qEAX('1')==1
              msg = sprintf('%s motor enable state remains on', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success=false;
              return
            end

            %Check the servo state
            if obj.hC.qSVO('1')==1
              msg = sprintf('%s servo state remains on', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success=false;
              return
            end

        end %disableAxis

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

        function isReferenced = isStageReferenced(obj)
          isReferenced = obj.hC.qFRF('1');
        end

        function printAxisStatus(obj)
          printAxisStatus@linearcontroller(obj); %call the superclass

          minPos = obj.hC.qTMN('1'); 
          minPos = obj.attachedStage.transformDistance(minPos);

          maxPos = obj.hC.qTMX('1'); 
          maxPos = obj.attachedStage.transformDistance(maxPos);
          fprintf('Controller minPos = %0.2f mm ; Controller maxPos = %0.2f mm\n', ... 
                minPos, maxPos)
        end


    end %close methods


end %close classdef 