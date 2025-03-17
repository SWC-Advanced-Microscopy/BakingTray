classdef singleAxisPriorController < linearcontroller
% singleAxisPriorController is a class that inherits linearcontroller and defines the interface between
% BakingTray and Prior's DLL for controlling a single axis (Z) stage.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
%
% INSTALLATION:
% To use this class you will need to download the Prior SDK:
% https://www.prior.com/technical-support/downloads/softwareall/matlab/
% Then add the x64 directory containing the DLL to the MATLAB path.
%
% API documentation
% The Prior SDK documentation is in the above archive you will download.
%
% To quickly test your stage you can try the Prior_Basic class in the ExampleCodeSnippets
% folder of this repository. This folder is not added to the MATLAB path during a
% BakingTray install, so just cd to it and test the class there.
%
%
% Example (connecting to a 100 mm travel range linear stage)
% tStage = genericStage;
% tStage.axisName='zaxis'
% tStage.minPos=0;
% tStage.maxPos=30;
%
% P=singleAxisPriorController(tStage);
% P.connect('com5')
%
%
% IMPORTANT NOTES
% The referencing command simply moves the stage to the home (zero) position. This therefore
% assumes an absolute encoder is present. This single axis class is therefore really designed
% for a Z stage. It is not quite as general purpose as it could be
%
% Rob Campbell - SWC AMF, initial commit Q2 2025


    properties
      % This property is filled in if needed during genericZaberController.connect
      tConnection % The COM connection is made here. The axis will be on hC
    end % close public properties

    % The following hidden properties are used for sending and receiving messages from
    % the controller.
    properties (Hidden)
        session      % Prior SDK session ID. Not user-settable
        errorCodes   % Dictionary mapping API status codes to what they mean
        messagePointer % empty string the is needed by the Prior DLL to return a message
    end % hidden properties



    methods

        % Constructor
        function obj=singleAxisPriorController(stageObject,logObject)

            if nargin<1
              stageObject=[];
            end
            if nargin<2
              logObject=[];
            end

            % Set up an empty variable with plenty of space for even a long message. This
            % is supplied as the last input argument to the PriorScientificSDK_cmd in
            % Prior_Basic.sendCommand.
            obj.messagePointer = blanks(1024);

            % Populate the errorCodes property with a dictionary linking API status numbers
            % to a string explaining what they mean.
            obj.genErrorCodeContainer


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
            % Destructor
            %
            % Clean up if connection worked

            if isempty(obj.session)
                return
            end

            fprintf('Disconnecting from Prior controller\n')

            % disconnect the COM connection to the controller
            obj.sendCommand('controller.disconnect')

            %close the session
            obj.lastAPIstatus = calllib('Prior','PriorScientificSDK_CloseSession',obj.session);
            obj.checkAPIstatus
        end % Destructor

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj,connectionDetails)
            % Connect to Prior stage
            %
            % success = singleAxisPriorStage.connect(connectionDetails)
            %
            % Purpose
            % Connect to the Priod controller at a defined COM port.
            %
            % Inputs
            % connectionDetails - a structure containing the com port identify. e.g.
            %     connectionDetails.COM = 'COM2' (The method can also cope with
            %     connectionDetails being a string, such as 'COM4', but this may not be
            %     future proof).
            %
            %


            if ischar(connectionDetails)
              tmp=connectionDetails;
              connectionDetails=struct;
              connectionDetails.COM = tmp;
            end

            if ~isstruct(connectionDetails)
              fprintf('singleAxisPriorController.connect expected connectionDetails to be a structure or COM port ID\n');
              delete(obj)
              return
            end

            if ~isstruct(connectionDetails)
              success = false;
              return
            end



            % Connect to the Prior library, which we will alias as "Prior"
            if not(libisloaded('Prior'))
                fprintf('Loading Prior SDK\n')
                loadlibrary('PriorScientificSDK','PriorScientificSDK.h','alias','Prior')
            else
                fprintf('Prior library is already loaded\n')
            end

            libfunctions('Prior');


            %% Initialize PriorSDK
            % This needs to be done before calling any other commands the API needs to
            % configure its internal data structures.
            fprintf('Initialising SDK.\n')
            obj.lastAPIstatus= calllib('Prior','PriorScientificSDK_Initialise');


            %% Create a session
            % The session is created along with  all the required data objects to go with it.
            % It ought to return non-negative session identifier which should be used when
            % sending commands or closing the session.
            fprintf('Setting up Prior SDK Session.\n')
            obj.session = calllib('Prior','PriorScientificSDK_OpenNewSession');

            %% Connect to the COM port
            fprintf('Connecting to COM %d.\n', comport)
            obj.com = comport;
            cmd = sprintf('controller.connect %d',obj.com);
            obj.sendCommand(cmd)
            obj.checkAPIstatus


            % With most controllers, the property "hC" is used as a handle for the API.
            % In this case we don't do this, instead using the sendCommand and checkAPIstatus
            % methods. We set hC to true just to indicate that this method has run.
            obj.hC = true;


            connected = obj.isControllerConnected;
            if ~connected
              fprintf('Failed to connect to controller\n')
              success = false;
              return
            end

            if obj.attachedStage.controllerUnitsInMM~=1
              obj.setPositionUnits('native');
            else
             obj.setPositionUnits('mm');
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
              reply = obj.getStageStepsPerMicron;
              if isempty(reply)
                fprintf('Prior single axis controller seems to be improperly connected\n')
              else
                success = true;
              end
            catch
              obj.logMessage(inputname(1),dbstack,7,'Failed to communicate with %s controller', obj.controllerID.controllerModel)
            end
        end %isControllerConnected



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function moving = isMoving(obj,~)
            isBusy = [];
            obj.sendCommand('controller.z.busy.get');
            if obj.lastAPIstatus==0
                isBusy = str2num(obj.lastResponse)>0;
            end
        end %isMoving



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function pos = axisPosition(obj,~)
            ready=obj.isAxisReady;
            if ~ready
              pos=[];
              return
            end

            pos = [];
            obj.sendCommand('controller.z.position.get');
            if obj.lastAPIstatus==0
                pos = str2double(obj.lastResponse);
                pos = pos * obj.attachedStage.controllerUnitsInMM; % convert to mm

                % Correctly return axis position if it is inverted
                pos = obj.attachedStage.invertDistance * (pos-obj.attachedStage.positionOffset);

                obj.attachedStage.currentPosition=pos;
            end

        end %axisPosition



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = relativeMove(obj, distanceToMove, ~)
          %TODO: abstract redundant code into linearcontroller.relativeMove
          %      singleAxisPriorController.relative move will then call the abstract function that
          %      returns the transformed move distance (or the anon function to calculate this)
          %      singleAxisPriorController just needs to pass these to the API

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
          stageUnits = obj.attachedStage.invertDistance * distanceToMove*obj.attachedStage.controllerUnitsInMM;
          stageUnits = round(stageUnits);

          cmd = sprintf('controller.z.move-relative %d', stageUnits);
          obj.sendCommand(cmd);

        end %relativeMove



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = absoluteMove(obj, targetPosition, ~)
            success=obj.isAxisReady;
            if ~success
              return
            end

            if ~obj.checkDistanceToMove(targetPosition)
              return
            end


            if ~obj.isMoveInBounds(targetPosition)
              success = false;
              return
            end

            obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));
            stageUnits = obj.attachedStage.invertDistance * (targetPosition-obj.attachedStage.positionOffset)*obj.attachedStage.controllerUnitsInMM;
            stageUnits = round(stageUnits);
            cmd = sprintf('controller.z.goto-position %d', stageUnits);
            obj.sendCommand(cmd);

          end %absoluteMove


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = stopAxis(obj, ~)
            obj.sendCommand('controller.stop.smoothly');
        end %stopAxis


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function posUnits = getPositionUnits(obj,~)
            posUnits = 'mm';
        end %getPositionUnits


        function success=setPositionUnits(obj, ~ ,~)
            % Controller units will always be in mm. BakingTray will never try to change
            % this and so we implement no way for doing so.
            success=true;
        end %setPositionUnits


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function minPos=getMinPos(obj)
            minPos=getMinPos@linearcontroller(obj);
        end % getMinPos

        function maxPos=getMaxPos(obj)
            maxPos=getMaxPos@linearcontroller(obj);
        end % getMaxPos


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % get or set speed and acceleration settings
        function velocity = getMaxVelocity(obj)
            ready=obj.isAxisReady;
            if ~ready
              return
            end

            velocity = [];
            obj.sendCommand('controller.z.speed.get')
            if obj.lastAPIstatus==0
                velocity = str2num(obj.lastResponse)/1E3;
            end
        end % getMaxVelocity

        function success = setMaxVelocity(obj, velocity)
            ready=obj.isAxisReady;
            success = false;

            if ~ready || ~isnumeric(velocity)
              return
            end

            cmd = sprintf('controller.z.speed.set %d', round(speed*1E3));
            obj.sendCommand(cmd)

            if obj.lastAPIstatus==0
              success=true;
            end
        end % setMaxVelocity

        function velocity = getInitialVelocity(obj)
            velocity=0;
        end % getInitialVelocity

        function success = setInitialVelocity(obj, velocity)
          %This can't/won't be set
          success = false;
        end % setInitialVelocity

        function accel = getAcceleration(obj)
          %This can't/won't be set
          success = false;
          accel = 1;
        end % getAcceleration

        function success = setAcceleration(obj, acceleration)
          %This can't/won't be set
          success = false;
        end % setAcceleration


        function success=enableAxis(obj)
            success=obj.isAxisReady;
        end %enableAxis


        function success=disableAxis(obj)
            success=obj.isAxisReady;
        end %disableAxis


        function success = referenceStage(obj)
          % We assume the prior stage has an absolute encoder. Referencing the stage
          % just moves it to the home position, which is zero.
          % NOTE -- this is fairly hard-coded and assumes the stage is being used as a
          % Z-jack

          obj.absoluteMove(0)
          success = false;
        end % referenceStage


        function isReferenced = isStageReferenced(obj)
          % NOTE: assumes an absolute encoder
          isReferenced = true;
        end

        function printAxisStatus(obj)
          printAxisStatus@linearcontroller(obj); %call the superclass
        end


    end %close methods


    % The following hidden methods are required for the Prior SDK to communicate with the
    % controller
    methods (Hidden)

        function checkAPIstatus(obj)
            % Check the API return status of last command
            %
            % Prior_Basic.checkAPIstatus
            %
            % Purpose
            % Run after each API command is sent. Checks the return status of the command
            % and prints to screen a message indicating the reason for failure should it
            % have failed.
            %
            % Inputs
            % none
            %
            % Outputs
            % none
            %

            if isempty(obj.lastAPIstatus)
                return
            end
            if obj.lastAPIstatus==0
                return
            end

            if obj.lastAPIstatus<0
                fprintf('Last command ERROR: %s\n', obj.errorCodes(obj.lastAPIstatus))
            end
        end % checkAPIstatus


        function genErrorCodeContainer(obj)
            % Populate errorCodes property
            %
            % Prior_Basic.genErrorCodeContainer
            %
            % Purpose
            % Populates a dictionary in .errorCodes with keys that are API status numbers
            % and values that are strings associating those to what they mean
            %
            % Inputs
            % none
            %
            % Outputs
            % none
            %

            CODES = [0, -10001, -10002, -10003, -10004, -10005, -10007, -10008, -10009, ...
                -10010, -10011, -10012, -10100, -10200, -10300, -10301];
            NAMES = {'OK', 'UNRECOGNISED_COMMAND', 'FAILED_TO_OPEN_PORT', ...
                'FAILED_TO_FIND_CONTROLLER', 'NOT_CONNECTED', 'ALREADY_CONNECTED', ...
                'INVALID_PARAMETERS', 'UNRECOGNISED_DEVICE', 'APP_DATA_PATH_ERROR', ...
                'LOAD_ERROR', 'CONTROLLER_ERROR', 'NOT_IMPLEMENTED', 'UNEXPECTED_ERROR', ...
                'SDK_NOT_INITIALISED', 'SDK_INVALID_SESSION', 'SDK_NO_MORE_SESSIONS'};
            obj.errorCodes = containers.Map(CODES,NAMES)
        end % genErrorCodeContainer


        function sendCommand(obj,commandString)
            % Send a command to a Prior stage
            %
            % Prior_Basic.sendCommand(commandString)
            %
            % Purpose
            % Sends the command specified in the string commandString to the Prior stage
            % controller. Outputs of the command are send to the .lastAPIstatus and the
            % .lastResponse properties
            %
            % Inputs
            % commandString - string that will be sent to the controller

            [obj.lastAPIstatus,~,obj.lastResponse] = ...
                calllib('Prior', 'PriorScientificSDK_cmd', ...
                    obj.session, commandString, obj.messagePointer);

            obj.checkAPIstatus

        end % sendCommand


        function stepsPerMicron = getStageStepsPerMicron(obj)
            % Return the number of stepper motor steps per micron
            %
            % Prior_Basic.getStageStepsPerMicron
            %
            % Inputs
            % none
            %
            % Outputs
            % stepsPerMicron - scalar defining the number of steps per micron travel. If
            %             the command failed it returns an empty vector.
            %

            stepsPerMicron = [];
            obj.sendCommand('controller.z.steps-per-micron.get');
            if obj.lastAPIstatus==0
                stepsPerMicron = str2double(obj.lastResponse);
            end
        end % getStageStepsPerMicron

    end % hidden methods

end %close classdef
