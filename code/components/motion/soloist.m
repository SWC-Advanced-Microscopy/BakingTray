classdef soloist < linearcontroller
% soloist is a class that inherits linearcontroller and defines the interface between
% BakingTray and Aerotech's MATLAB library. In effect, this is a glue class.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% To use soloist, install the Aerotech support files that came with your device. You should
% ensure you ask Aerotech to supply the MATLAB libraries with the product. 


    properties
      % The following are inherited properties from linearcontroller
      % controllerID - the information necessary to build a connected object
      %
      %
      % This class is written assuming you are connecting over ethernet.
      %
      % Ethernet
      % controllerID.interface='ethernet'
      % controllerID.ID='123456789012'
      %
      % Serial [NOT IMPLEMENTED]
      % controllerID.interface='rs232'
      % controllerID.COM='COM1'
      % controllerID.baudrate=115200


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
              SoloistDisconnect(obj.hC)
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

          H = SoloistConnect;

          if isempty(H)
            fprintf('Failed to find a Soloist\n');
            success=false;
            return
          end

          % TODO: Somehow test whether this is the correct device. 
          

          obj.hC = H; % This is the handle that needs to fed into all the Soloist commands.

          tName = SoloistInformationGetName;
          fprintf('Connected to %s\n', tName)

          % TODO Check that an axis is connected
          if 0
            fprintf('No stages found on %s controller. FAILED TO CONNECT.\n',  tName)
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
            SoloistMotionMoveInc(obj.hC,distanceToMove,obj.attachedStage.defaultSpeed)

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
            SoloistMotionMoveAbs(obj.hC,targetPosition,obj.attachedStage.defaultSpeed)
        end %absoluteMove


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = stopAxis(obj, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            SoloistMotionHalt(obj.hC)
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

            SoloistMotionEnable(obj.hC)

            %TODO - Check the enable state

            success=true;
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
          SoloistMotionHome(obj.hC)
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

    methods (Hidden)
      function libsPresent = aerotechLibsPresent(obj)
        % Return true if the Aerotech MATLAB libraries are present
        libsPresent = ~isempty(which(obj.solistConnectFunctionName))
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

        addpath(obj.aerotechLibPath)

        if ~obj.aerotechLibsPresent
          fprintf('AEROTECH LIBRAY PATH DOES NOT CONTAIN EXPECTED FUNCTIONS AT: %s\n',obj.addAerotechLibsToPath)
          success=false;
          return
        end

        success=true;
      end %addAerotechLibsToPath

    end % Hidden methods


end %close classdef 
