classdef genericZaberController < linearcontroller
% genericZaberController is a class that inherits linearcontroller and defines the interface between
% BakingTray and Zabers's Motion Librarys.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% INSTALLATION:
% To use this class you will need the Zaber Motion Library MATLAB Toolbox:
% https://www.zaber.com/software/docs/motion-library/ascii/tutorials/install/matlab/
%
% The Zaber interface is documented here:
% https://www.zaber.com/software/docs/motion-library/ascii/references/matlab/
% https://www.zaber.com/software/docs/motion-library/ascii/tutorials/initialize/
%
%
% NOTE:
% This class currently connects to a single X-MX[ABC] device and assumes control of 
% the first axis. The class does not handle multiple axes. 
%
% IMPORTANT: if using native units, you must set controllerUnitsInMM to the correct 
%            value. If you are not using native units, this property must be 1. If
%            controllerUnitsInMM are set to a value other than 1 when the stage
%            connects, then the units of the stage are set to native automatically. 
%            Otherwise they are se to mm.

    properties
      % The following are inherited properties from linearcontroller
      % controllerID - the information necessary to build a connected PI_GCS_Controller object
      %
      % This property is filled in if needed during C891.connect
      tConnection % The COM connection is made here. The axis will be on hC
      velocityUnits % We store here how speeds are defined (mm/s or um/s)
      accelerationUnits % We store here how accelerations are defined (mm/s^2 or um/s^2)
    end % close public properties



    methods

        % Constructor
        function obj=genericZaberController(stageObject,logObject)

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
            if ~isempty(obj.tConnection)
              fprintf('Closing connection to Zaber controller\n')
              obj.tConnection.close();
            end
        end % Destructor

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj,connectionDetails)
            % connectionDetails should supply the serial params in this form:
            % connectionDetails.COM = 'COM2'

            if ischar(connectionDetails)
              tmp=connectionDetails;
              connectionDetails=struct;
              connectionDetails.COM = tmp;
            end

            if ~isstruct(connectionDetails)
              fprintf('genericZaberController.connect expected connectionDetails to be a structure or COM port ID\n');
              delete(obj)
              return
            end

            if ~isstruct(connectionDetails)
              success = false;
              return
            end

            %Attempt to connect to the Zaber controller
            try
              import zaber.motion.Library;
              import zaber.motion.ascii.Connection;
              import zaber.motion.Units;
              Library.enableDeviceDbStore();
            catch ME 
              fprintf('\n\n ** Failed to connect to the Zaber Motion Library. Is it installed?\n\n **')
              rethrow(ME)
            end


            obj.tConnection = Connection.openSerialPort(connectionDetails.COM);
            try
              deviceList = obj.tConnection.detectDevices();
              fprintf('Found Zaber devices.\n')
            catch ME
              fprintf('Failed to find Zaber devices.\n')
              obj.tConnection.close();
              rethrow(ME);
            end

            if isempty(deviceList)
              fprintf('Failed to find Zaber devices.\n')
              return
            end

            % Look for a controller device in the list of available devices. 
            % We have to search, because if the user has a joytick configured it
            % will appear as a device too but it won't have a motor connected to it. 
            controllerInd = [];
            for ii=1:length(deviceList)
              if contains(char(deviceList(ii)),'X-MC')
                controllerInd = ii;
              end
            end

            if isempty(controllerInd)
              fprintf('\n\nFailed to find a Zaber controller in devices list:\n')
              arrayfun(@(x) fprintf('%s\n',x), deviceList)
              fprintf('\n')
              return
            end

            obj.hC = deviceList(controllerInd).getAxis(1);


            connected = obj.isControllerConnected;
            if ~connected
              fprintf('Failed to connect to controller\n')
              success = false;
              return
            end

            if obj.attachedStage.controllerUnitsInMM~=1
              obj.setPositionUnits('native')
            else
             obj.setPositionUnits('mm')
           end

            % Reference stage if it is not currently referenced
            if ~obj.isStageReferenced
               obj.referenceStage;
            end

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
              reply = obj.hC.getPeripheralName; 
              if isempty(reply)
                fprintf('No reply from Zaber controller\n')
              else
                success = true;
              end
            catch
              obj.logMessage(inputname(1),dbstack,7,'Failed to communicate with %s controller', obj.controllerID.controllerModel)
            end
        end %isControllerConnected



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function moving = isMoving(obj,~)
            moving = obj.hC.isBusy;
        end %isMoving



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = axisPosition(obj,~)
            ready=obj.isAxisReady;
            if ~ready
              pos=[];
              return
            end

            pos = obj.hC.getPosition(obj.attachedStage.positionUnits);
            pos = pos*obj.attachedStage.controllerUnitsInMM;
            obj.attachedStage.currentPosition=pos;
        end %axisPosition



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = relativeMove(obj, distanceToMove, ~)
          %TODO: abstract redundant code into linearcontroller.relativeMove
          %      genericZaberController.relative move will then call the abstract function that
          %      returns the transformed move distance (or the anon function to calculate this)
          %      genericZaberController just needs to pass these to the API

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
            obj.hC.moveRelative(distanceToMove,obj.attachedStage.positionUnits,false)
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
            obj.hC.moveAbsolute(targetPosition,obj.attachedStage.positionUnits,false)
        end %absoluteMove


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = stopAxis(obj, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            success=obj.hC.stop;
        end %stopAxis


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = getPositionUnits(obj,~)
            tUnits = char(obj.attachedStage.positionUnits);
            if strcmp(tUnits,'LENGTH_MILLIMETRES')
              pos='mm';
            elseif strcmp(tUnits,'LENGTH_MICROMETRES')
              pos='um';
            end
        end %getPositionUnits


        function success=setPositionUnits(obj,controllerUnits,~)
            import zaber.motion.Units
            if strcmp(controllerUnits,'mm')
              obj.attachedStage.positionUnits = Units.LENGTH_MILLIMETRES;
              obj.velocityUnits = Units.VELOCITY_MILLIMETRES_PER_SECOND;
              obj.accelerationUnits = Units.ACCELERATION_MILLIMETRES_PER_SECOND_SQUARED;
            elseif strcmp(controllerUnits,'um')
              obj.attachedStage.positionUnits = Units.LENGTH_MICROMETRES;
              obj.velocityUnits = Units.VELOCITY_MICROMETRES_PER_SECOND;
              obj.accelerationUnits = Units.ACCELERATION_MICROMETRES_PER_SECOND_SQUARED;
            elseif strcmp(controllerUnits,'native')
              obj.attachedStage.positionUnits = Units.NATIVE;
              obj.velocityUnits = Units.NATIVE;
              obj.accelerationUnits = Units.NATIVE;
            else
              fprintf('Unknown position units "%s"\n', controllerUnits)
              success = false;
            end
            success=true;
        end %setPositionUnits


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function minPos=getMinPos(obj)
            minPos=getMinPos@linearcontroller(obj);
        end

        function maxPos=getMaxPos(obj)
            maxPos=getMaxPos@linearcontroller(obj);

        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % get or set speed and acceleration settings
        function velocity = getMaxVelocity(obj)
            ready=obj.isAxisReady;
            if ~ready
              return
            end
            velocity = obj.hC.getSettings.get('maxspeed', obj.velocityUnits);
        end

        function success = setMaxVelocity(obj, velocity)
             %obj.hC.genericCommand('set maxspeed 204850') %but it's in ticks
            ready=obj.isAxisReady;
            success = false;

            if ~ready || ~isnumeric(velocity)
              return
            end

            obj.hC.getSettings.set('maxspeed', velocity, obj.velocityUnits)

            currentVelocity = obj.getMaxVelocity;
            switch obj.getPositionUnits
            case 'mm'
              currentVelocity = round(currentVelocity,4);
            case 'um'
              currentVelocity = round(currentVelocity,1);
            end

            success = currentVelocity==velocity;
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
            accel = obj.hC.getSettings.get('accel', obj.accelerationUnits);
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
            obj.hC.getSettings.set('accel', acceleration, obj.accelerationUnits)

            currentAccel = obj.getAcceleration;
            switch obj.getPositionUnits
            case 'mm'
              currentAccel = round(currentAccel,1);
            case 'um'
              currentAccel = round(currentAccel,-3);
            end

            success = currentAccel==acceleration;
        end


        function success=enableAxis(obj)
            success=obj.isAxisReady;
        end %enableAxis


        function success=disableAxis(obj)
            success=obj.isAxisReady;
        end %disableAxis


        function success = referenceStage(obj)
          try
            obj.hC.home
            success = true;
          catch
            success = false;
          end
        end


        function isReferenced = isStageReferenced(obj)
          import zaber.motion.ascii.Warnings
          import zaber.motion.ascii.WarningFlags
          W = Warnings.getFlags(obj.hC.getWarnings);
          
          if isempty(W)
              % No warnings so must be homed
              isReferenced = true;
              return
          end
          W = char(W);
          if contains(W,'WR') || contains(W,'WH')
              isReferenced = false;
          else
              isReferenced = true;
          end
    
        end

        function printAxisStatus(obj)
          printAxisStatus@linearcontroller(obj); %call the superclass
          % TODO : ADD MAX AND MIN POS REPORTING
        end


    end %close methods


end %close classdef
