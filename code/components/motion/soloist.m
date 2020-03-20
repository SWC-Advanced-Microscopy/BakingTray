classdef soloist < linearcontroller
% soloist is a class that inherits linearcontroller and defines the interface between
% BakingTray and Aerotech's MATLAB library. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use soloist, install the Aerotech support files that came with your device. You should
% ensure you ask Aerotech to supply the MATLAB libraries with the product. 
%
%
% Examples
% %% Make a stage and attach it to the controller object
% >> STAGE = AVS_100_25;
% >> STAGE.axisName='someName'; %Does not matter for this toy example
% >> SOLO = soloist(STAGE); %Create  control class
%
% %% Connect to the controller over ethernet
% >> controllerID.interface='ethernet';
% >> controllerID.ID= '613880-1-1'; %The controller name
%
% Now we are ready to communicate with the device and connect to it:
%
% >> SOLO.connect(controllerID)


    properties
      % The following are inherited properties from linearcontroller
      % controllerID - the information necessary to build a connected object
      %
      %
      % This class is written assuming you are connecting over ethernet.
      % The controller ID string should be that shown in the Aerotech
      % config software where you mapped the device. At the moment this 
      % is just a safety feature to confirm that we have connected to the
      % correct device. 
      %
      % Ethernet
      % controllerID.interface='ethernet'
      % controllerID.ID='63231-1-1'
      %


      aerotechLibPath = 'C:\Program Files (x86)\Aerotech\Soloist\Matlab\x64'
      solistConnectFunctionName = 'SoloistConnect'
    end % close public properties


    methods

        % Constructor
        function obj=soloist(stageObject,logObject)

            if nargin<1
              stageObject=[];
            end
            if nargin<2
              logObject=[];
            end

            obj.maxStages=1;

            % Try to add Aerotech MATLAB library to path and bail out if this fails. 
            success = obj.addAerotechLibsToPath;
            if success==false
              delete(soloist)
              return
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
              fprintf('Closing connection to %s controller\n', 'Soloist')
              obj.disableAxis;
              SoloistDisconnect(obj.hC);
            end
        end % Destructor

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj,connectionDetails)

          if ~isstruct(connectionDetails)
            success = false;
            return
          end

          if ~isfield(connectionDetails,'interface')
            fprintf('No connectionDetails.interface field. Can not connect to %s.\n', ...
                connectionDetails.controllerModel)
            success = false;
            return
          end

          H = SoloistConnect;

          if isempty(H)
            fprintf('Failed to find a Soloist\n');
            success=false;
            return
          end

          if length(H)>1
            fprintf('Found more than one Soloist device. This situation is not catered for.\n')
            success=false;
            return
          end

          obj.hC = H; % This is the handle that needs to fed into all the Soloist commands.

          tName = SoloistInformationGetName(obj.hC);
          if ~strcmp(tName,connectionDetails.ID)
            fprintf('You requested to connect to device %s but device %s was found.\nQUITTING\n', ...
            tName, connectionDetails.ID);
            success=false;
            return
          end
          fprintf('Connected to %s\n', tName)

          % TODO - Check that an axis is connected
          if 0
            fprintf('No stages found on %s controller. FAILED TO CONNECT.\n',  tName)
            success = false;
            return
          end

          % Set motions to be non-blocking by default
          obj.setToNonBlocking;

          % The AVS-100 came with a rather fast acceleration out of the box. We tone it
          % down a little here.
          obj.setAcceleration(obj.attachedStage.defaultAcceleration);

          %Enable the stage
          enabled = obj.enableAxis;
          if ~enabled
            fprintf('Failed to enable axis on %s\n', obj.controllerID.controllerModel)
            success = false;
            return
          end
          success=true;

          % Reference the stage (Not all controller/stage combinations need this so the method is not defined in this class here)
          obj.referenceStage;

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
                %Contains a string bearing the name of the controller
                reply = SoloistInformationGetName(obj.hC);
                if isempty(reply)
                    fprintf('No reply from PI controller with qIDN command\n')
                else
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

            moving = obj.readAxisBit(4);
        end %isMoving



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = axisPosition(obj,~)
            ready=obj.isAxisReady;
            if ~ready
              pos=[];
              return
            end

            pos = SoloistStatusGetItem(obj.hC, SoloistStatusItem(1));
            pos = obj.attachedStage.invertDistance * (pos-obj.attachedStage.positionOffset) * obj.attachedStage.controllerUnitsInMM;
            obj.attachedStage.currentPosition=pos;
        end %axisPosition



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = relativeMove(obj, distanceToMove, ~)
          %TODO: abstract redundant code into linearcontroller.relativeMove
          %      soloist.relative move will then call the abstract function that
          %      returns the transformed move distance (or the anon function to calculate this)
          %      soloist just needs to pass these to the API

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
            SoloistMotionMoveInc(obj.hC,distanceToMove,obj.attachedStage.maxMoveVelocity)

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
            SoloistMotionMoveAbs(obj.hC,targetPosition,obj.attachedStage.maxMoveVelocity)
        end %absoluteMove


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = stopAxis(obj, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            SoloistMotionAbort(obj.hC)
        end %stopAxis


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = getPositionUnits(~,~)
              pos='mm'; %The units of the C-891 are fixed at mm and can't be queried %TODO -- is this the case for all PI controllers?
        end %getPositionUnits

        function success=setPositionUnits(obj,controllerUnits,~)
          % I think the Soloist works only in mm
            if ~strcmp(controllerUnits,'mm')
              obj.logMessage(inputname(1),dbstack,6,'Soloist works only in mm') % (probably)
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
              velocity=[];
              return
            end
            velocity=obj.attachedStage.maxVelocity;
        end

        function success = setMaxVelocity(obj, velocity)
            ready=obj.isAxisReady;
            success = false;

            if ~ready || ~isnumeric(velocity)
              return
            end

            % The target velocity is not stored in the controller so
            % we must instead store in the stage object
            if velocity>obj.attachedStage.velocityCapMax
                fprintf('Capping velocity to %d\n',obj.attachedStage.velocityCapMax)
                velocity=obj.attachedStage.velocityCapMax;
            end

            obj.attachedStage.maxVelocity = velocity;
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
            fprintf('ACCELERATION FROM SOLOIST NOT READ BACK\n');
            accel=1;
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

            SoloistMotionSetupRampRateAccel(obj.hC,acceleration)
            success=true;
        end


        function success=enableAxis(obj)
            success=obj.isAxisReady;
            if ~success
              fprintf('Unable to enable axis. It is reported as not being ready\n')
              return
            end

            SoloistMotionEnable(obj.hC)
            success = obj.readAxisBit(1)

            success=true;
        end %enableAxis


        function success=disableAxis(obj)
            success=obj.isAxisReady;
            if ~success
              fprintf('Unable to disable axis. It is reported as not being ready\n')
              return
            end

            SoloistMotionDisable(obj.hC)
        end %disableAxis


        function success = referenceStage(obj)
          SoloistMotionHome(obj.hC)
          success=obj.isStageReferenced;
        end


        function isReferenced = isStageReferenced(obj)
            isReferenced = obj.readAxisBit(2);
        end

        function printAxisStatus(obj)
          printAxisStatus@linearcontroller(obj); %call the superclass
        end


    end %close methods


    methods (Hidden)
        function libsPresent = aerotechLibsPresent(obj)
            % Return true if the Aerotech MATLAB libraries are present
            libsPresent = exist(obj.solistConnectFunctionName,'file');
        end % aerotechLibsPresent


        function success = addAerotechLibsToPath(obj)
            % Add the Aerotech MATLAB libraries to the path if needed
            if obj.aerotechLibsPresent
              success=true;
                return
            end

            if exist(obj.aerotechLibPath,'dir')
                fprintf('CAN NOT FIND AEROTECH MATLAB LIBRARIES AT: %s\n',obj.addAerotechLibsToPath)
                success=false;
                return
            end
  
            if ~obj.aerotechLibsPresent
                fprintf('AEROTECH LIBRAY PATH DOES NOT CONTAIN EXPECTED FUNCTIONS AT: %s\n',obj.addAerotechLibsToPath)
                success=false;
                return
            end

            success=true;
        end %addAerotechLibsToPath


        function setToNonBlocking(obj)
            % Conduct motions in background (non-blocking)
            SoloistMotionWaitMode(obj.hC,0)
        end %setToNonBlocking


        function setToBlocking(obj)
            % Conduct motions in the foreground (blocking)
            SoloistMotionWaitMode(obj.hC,1)
        end %setToBlocking


        function tBit = readAxisBit(obj,bitToRead)
            % Reads axis status bit and returns as a number (1 or 0)
            bitToRead = bitToRead-1;
            binWord = dec2bin(SoloistStatusGetItem(obj.hC, SoloistStatusItem('AxisStatus')));
            tBit = str2num(binWord(end-bitToRead));
        end % readAxisBit

    end % Hidden methods


end %close classdef 
