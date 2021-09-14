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
% The support package needs to be added to the MATLAB path and is probably
% located at: C:\Program Files (x86)\Physik Instrumente (PI)\Software Suite\MATLAB_Driver
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
      % controllerID.COM=8
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

            obj.maxStages=1;
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
            success = false;
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
          knownWorkingControllers = {'C-891', 'C-863', 'C-663'}; 
          switch connectionDetails.controllerModel
            case knownWorkingControllers
              % pass
            otherwise
              % We haven't tested this controller or there is a typo
              fprintf('Controller %s is untested. Proceed with caution!\n', connectionDetails.controllerModel)
          end


          %Attempt to connect to the PI controller using the chosen interface
          try
            PI_Controller = PI_GCS_Controller;
            switch lower(connectionDetails.interface)
              case 'usb'
                fprintf('Attempting to connect to %s with serial number %s\n', connectionDetails.controllerModel, connectionDetails.ID);
                obj.hC = PI_Controller.ConnectUSB(connectionDetails.ID);
              case 'rs232'
                fprintf('Attempting RS232 connection on port %d with baud rate %d\n',connectionDetails.COM, connectionDetails.baudrate);
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
              success = false;
              rethrow(lasterror)
          end


          connected = obj.isControllerConnected;
          if ~connected
            fprintf('Failed to connect to controller\n')
            success = false;
            return
          end

          %Check that an axis is connected
          if isempty(obj.hC.qSAI_ALL)
            fprintf('No stages found on %s controller. FAILED TO CONNECT.\n',  obj.controllerID.controllerModel)
            success = false;
            return
          end

          %Enable the stage
          enabled = obj.enableAxis;
          if ~enabled
            fprintf('Failed to enable axis on %s\n', obj.controllerID.controllerModel)
            success = false;
            return
          end
          success=true;

          % The PI code turns on a load of warnings. So we turn them off here
          warning off 
        end %connect

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = isControllerConnected(obj)
            success = false;
            if isempty(obj.hC)
              fprintf('The controller property "hC" is empty.\n')
              obj.logMessage(inputname(1),dbstack,7,'No attempt to connect to the controller has been made')
              return
            end

            try 
              reply=obj.hC.qIDN; %Contains a string bearing the name of the controller (e.g. C-891)
              if isempty(reply)
                  fprintf('No reply from PI controller with qIDN command\n')
              elseif ~isempty(strfind(reply, obj.controllerID.controllerModel))
                success=true;
              else
                  fprintf('You asked to connect to a %s controller but it returned:\n%s\n',...
                      obj.controllerID.controllerModel, reply)
                  fprintf('You may need make a new class for this controller\n')
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
            pos = obj.attachedStage.invertDistance * (pos-obj.attachedStage.positionOffset) * obj.attachedStage.controllerUnitsInMM;
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
              success = false;
              return
            end
          % </redundant>

            obj.logMessage(inputname(1),dbstack,1,sprintf('moving by %0.f',distanceToMove));
            distanceToMove = obj.attachedStage.invertDistance * distanceToMove/obj.attachedStage.controllerUnitsInMM;
            obj.hC.MVR('1',distanceToMove);

        end %relativeMove



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = absoluteMove(obj, targetPosition, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            if ~obj.isMoveInBounds(targetPosition)
              success = false;
              return
            end

            obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));
            targetPosition = obj.attachedStage.invertDistance * (targetPosition-obj.attachedStage.positionOffset)/obj.attachedStage.controllerUnitsInMM;
            obj.hC.MOV('1',targetPosition);
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
              pos='mm'; %The units are fixed in mm
        end %getPositionUnits

        function success=setPositionUnits(obj,controllerUnits,~)
            if ~strcmp(controllerUnits,'mm')
              obj.logMessage(inputname(1),dbstack,6,'PI controllers work only in mm')
              success = false;
            end
            success=true;
        end %setPositionUnits


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function minPos=getMinPos(obj)
            minPos=getMinPos@linearcontroller(obj);

            if isempty(minPos)
              minPos = obj.hC.qTMN('1'); 
              minPos = (minPos-obj.attachedStage.positionOffset)/obj.attachedStage.controllerUnitsInMM;
            end
        end

        function maxPos=getMaxPos(obj)
            maxPos=getMaxPos@linearcontroller(obj);

            if isempty(maxPos)
              maxPos = obj.hC.qTMX('1'); 
              maxPos = (maxPos-obj.attachedStage.positionOffset)/obj.attachedStage.controllerUnitsInMM;
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
            success = false;

            if ~ready || ~isnumeric(velocity)
              return
            end

            obj.hC.VEL('1',velocity);
            success = obj.getMaxVelocity==velocity;
        end

        function velocity = getInitialVelocity(obj)
            velocity=0;
        end

        function success = setInitialVelocity(obj, velocity)
          %This can't be set
          success = false;
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
              success = false;
              return
            end
            obj.hC.ACC('1',acceleration);
            success = obj.getAcceleration==acceleration;
        end


        function success=enableAxis(obj)
            success=obj.isAxisReady;
            if ~success
              fprintf('Unable to enable axis. It is reported as not being ready\n')
              return
            end

            if strcmp(obj.controllerID.controllerModel, 'C-891')
              obj.hC.EAX('1',1); %enable the axis
            end
    
            obj.hC.SVO('1',1); %enable the servo


            %Check the enable state
            if strcmp(obj.controllerID.controllerModel, 'C-891') && obj.hC.qEAX('1')==0
              msg = sprintf('%s motor enable state remains off', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success = false;
              return
            end

            %Check the servo state
            if obj.hC.qSVO('1')==0
              msg = sprintf('%s servo state remains off', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success = false;
              return
            end

        end %enableAxis


        function success=disableAxis(obj)
            success=obj.isAxisReady;
            if ~success
              fprintf('Unable to disable axis. It is reported as not being ready\n')
              return
            end

            obj.hC.SVO('1',0); %disable the servo

            if strcmp(obj.controllerID.controllerModel, 'C-891')
              obj.hC.EAX('1',0); %disable the axis
            end


            %Check the enable state
            if strcmp(obj.controllerID.controllerModel, 'C-891') && obj.hC.qEAX('1')==1
              msg = sprintf('%s motor enable state remains on', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success = false;
              return
            end

            %Check the servo state
            if obj.hC.qSVO('1')==1
              msg = sprintf('%s servo state remains on', obj.controllerID.controllerModel);
              obj.logMessage(inputname(1),dbstack,5,msg)
              success = false;
              return
            end

        end %disableAxis


        function success = referenceStage(obj)
          % This could be different between stages and controllers, so define in controller class for now
          fprintf('\n* Skipping stage referencing: not implemented for this controller.\n')
          success=true;
        end


        function isReferenced = isStageReferenced(obj)
          isReferenced=obj.hC.qFRF('1');
        end

        function printAxisStatus(obj)
          printAxisStatus@linearcontroller(obj); %call the superclass

          minPos = obj.hC.qTMN('1'); 
          maxPos = obj.hC.qTMX('1'); 
          fprintf('Controller raw minPos = %0.2f mm ; Controller raw maxPos = %0.2f mm\n', ... 
                minPos, maxPos)

          minPos = (minPos-obj.attachedStage.positionOffset)/obj.attachedStage.controllerUnitsInMM;
          maxPos = (maxPos-obj.attachedStage.positionOffset)/obj.attachedStage.controllerUnitsInMM;

          fprintf('Controller converted minPos = %0.2f mm ; Controller converted maxPos = %0.2f mm\n', ... 
                minPos, maxPos)


        end


    end %close methods


end %close classdef 