classdef Prior_Basic < handle
	% Prior_Basic
	%
	% A simple class for interacting with a Prior single axis (Z) stage controller.
	%
    % 
	% Example
	% P = Prior_Basic(5)
	% P.getStagePos
	% P.getSpeed % Get speed of the stage in mm/s
	% P.setSpeed(1) % Set speed of the stage in mm/s
	% P.getStagePos % Get stage position in mm
	% P.setStagePos(5.5) % Go to the 5.5 mm position
    %
    %
	% Rob Campbell, SWC AMF, initial commit Q1 2025



	properties
		com            % COM port ID (defined by user as constructor input arg)
		lastAPIstatus  % The status code returned by the last run command
		lastResponse   % The last response from the controller is kept here
	end % properties


	properties (Hidden)
		session      % Prior SDK session ID. Not user-settable
		errorCodes   % Dictionary mapping API status codes to what they mean
		messagePointer % empty string the is needed by the Prior DLL to return a message
	end % hidden properties



	methods
		function obj = Prior_Basic(comport)
			% obj = Prior_Basi
			%
			% Constructor
			%
			% The constructor connects to a user-defined COM port and sets up the API.
			%
			% Inputs
			% commport - scalar defining the com port number corresponding to the Prior
			%       controller. e.g. 5
			%
			% Example
			% P = Prior_Basic(5)
			% P.getStagePos
			% P.getSpeed % Get speed of the stage in mm/s
			% P.setSpeed(1) % Set speed of the stage in mm/s
			% P.getStagePos % Get stage position in mm
			% P.setStagePos(5.5) % Go to the 5.5 mm position


		    if nargin<1 || isempty(comport) || ~isnumeric(comport)
				fprintf('Provide com port to connect to as an integer\n')
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

			% Set up an empty variable with plenty of space for even a long message. This
			% is supplied as the last input argument to the PriorScientificSDK_cmd in
			% Prior_Basic.sendCommand.
			obj.messagePointer = blanks(1024);

			% Populate the errorCodes property with a dictionary linking API status numbers
			% to a string explaining what they mean.
			obj.genErrorCodeContainer

			%% Initialise PriorSDK
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

		end % Prior_Basic


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



		function sdkVersion = getSDKversion(obj)
			% Print SDK version to screen
			%
			% Prior_Basic.getSDKversion
			%
			% Inputs
			% none
			%
			% Outputs
			% sdkVersion - The Prior SDK version returned as a string. Returns 
			%			empty if command failed.
			%

			sdkVersion = [];
			[obj.lastAPIstatus, obj.lastResponse] = calllib('Prior','PriorScientificSDK_Version', obj.messagePointer);
			obj.checkAPIstatus
			if obj.lastAPIstatus==0
				sdkVersion = obj.lastResponse;
			end
		end % getSDKversion


		function stageName = getStageName(obj)
			% Print stage name to screen
			%
			% Prior_Basic.getStageName
			%
			% Inputs
			% none
			%
			% Outputs
			% stageName - The stage name returned as a string. Returns empty if 
			%			command failed.
			%
			
			stageName = [];
			obj.sendCommand('controller.stage.name.get');
			if obj.lastAPIstatus==0
				stageName = obj.lastResponse;
			end
		end % getStageName


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


		function stagePos = getStagePos(obj)
			% Return the absolute position of the stage in mm
			%
			% Prior_Basic.getStagePos
			%
			% Inputs
			% none
			%
			% Outputs
			% stagePos - scalar defining the position of the stage in mm. If the command
			% 			 failed it returns an empty vector.
			%

			stagePos = [];
			obj.sendCommand('controller.z.position.get');
			if obj.lastAPIstatus==0
				stagePos = str2double(obj.lastResponse)/1E4; % convert to mm
			end
		end % getStagePos


		function gotoPos(obj,posInMM)
			% Move stage to an absolute position defined in mm
			%
			% Prior_Basic.gotoPos(posInMM)
			%
			% Inputs
			% posInMM - position to which the stage should move in mm
			%
			% Outputs
			% none
			%

			if nargin<2
				fprintf('Must supply a position in mm to go to\n')
				return
			end

			if ~isnumeric(posInMM) || ~isscalar(posInMM)
				fprintf('posInMM should be a numeric scalar\n')
				return
			end

			% Convert the value in mm to one in 100 nm steps
			stagePosUnits = round(posInMM * 1E4);
			cmd = sprintf('controller.z.goto-position %d', stagePosUnits);
			obj.sendCommand(cmd);
		end % gotoPos


		function moveRelativeposInMM(obj,posByInMM)
			% Move stage to a relative position defined in mm
			%
			% Prior_Basic.moveRelativeposInMM(posByInMM)
			%
			% Inputs
			% posByInMM - How much to move the stage by in mm.
			%
			% Outputs
			% none
			%

			if nargin<2
				fprintf('Must supply a position in mm to go to\n')
				return
			end

			if ~isnumeric(posByInMM) || ~isscalar(posByInMM)
				fprintf('posByInMM should be a numeric scalar\n')
				return
			end

			% Convert the value in mm to one in 100 nm steps
			stagePosUnits = round(posByInMM * 1E4);
			cmd = sprintf('controller.z.move-relative %d', stagePosUnits);
			obj.sendCommand(cmd);
		end % moveRelative


		function stop(obj)
			% Stop the stage
			%
			% Prior_Basic.stop
			%
			% Inputs
			% none
			%
			% Outputs
			% none
			%

			obj.sendCommand('controller.stop.smoothly');

		end % getIsBusy


		function isBusy = getIsBusy(obj)
			% Is the stage busy (moving)?
			%
			% Prior_Basic.getIsBusy
			%
			% Inputs
			% none
			%
			% Outputs
			% isBusy - bool. true (1) if busy false (0) if not busy. Returns empty 
			%		if the command failed.
			%

			isBusy = [];
			obj.sendCommand('controller.z.busy.get');
			if obj.lastAPIstatus==0
				isBusy = str2num(obj.lastResponse)>0;
			end
		end % getIsBusy


		function speed = getSpeed(obj)
			% Get stage speed in mm per second
			%
			% Prior_Basic.getSpeed
			%
			% Inputs
			% none
			%
			% Outputs
			% speed - Scalar defining the stage speed in mm per second. Returns empty if
			%         the command failed.
			%

			speed = [];
			obj.sendCommand('controller.z.speed.get')
			if obj.lastAPIstatus==0
				speed = str2num(obj.lastResponse)/1E3;
			end
		end % getSpeed


		function setSpeed(obj,speed)
			% Set stage speed in mm/sec
			%
			% Prior_Basic.setSpeed
			%
			% Inputs
			% speed - speed at which the stage should move in mm/s.
			%
			% Outputs
			% none
			%

			if nargin<2
				fprintf('Must supply a speed in mm/s\n')
				return
			end

			if ~isnumeric(speed) || ~isscalar(speed)
				fprintf('speed should be a numeric scalar\n')
				return
			end
			
			if speed<=0
				fprintf('speed should be a positive numvber\n')
				return
			end

			cmd = sprintf('controller.z.speed.set %d', round(speed*1E3));
			obj.sendCommand(cmd)
		end % setSpeed

	end % methods



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
				-10010,	-10011, -10012, -10100, -10200, -10300, -10301];
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

		end	% sendCommand

	end % hidden methods


end % Prior_Basic
