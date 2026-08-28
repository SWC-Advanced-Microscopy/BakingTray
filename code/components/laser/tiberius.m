classdef tiberius < laser & loghandler
%%  tiberius - control class for tiberius lasers
%
%
% Example
% M = tiberius('COM1');
%
% Laser control component for Tiberius lasers from ThorLabs.
%
% tiberius inherits the laser abstract class. For the API documentation (what each
% of the shared methods is meant to do) see the doc text in laser.m. The methods
% below that implement that API carry only a short note plus a pointer to the
% matching laser method. Methods specific to the Tiberius (the async reply handlers)
% carry their own full doc text.
%
% Rob Campbell - SWC 2021


    properties (Constant,Hidden)
        % Tiberius serial queries — single-sourced so each string appears once. These
        % are the queries issued by the status poll (see pollSerial). The Tiberius has
        % no serial query for output power or on/off state.
        CMD_QUERY_SHUTTER    = 'S?'      % shutter state (3rd character is 1 when open)
        CMD_QUERY_WAVELENGTH = 'W?'      % current wavelength in nm
        CMD_QUERY_MODELOCK   = 'STATUS?' % modelock state (R = modelocked, N = not)
    end


    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = tiberius(serialComms,logObject)
            % tiberius
            %
            % Purpose
            % Constructor. Connect to a Tiberius laser on the specified serial port and
            % start the background status poller.
            %
            % Inputs
            % serialComms - [string] the serial port to connect to. e.g. 'COM1'
            % logObject   - [optional] a loghandler-derived object used for logging

            if nargin<1
                error('tiberius requires at least one input argument: you must supply the laser COM port as a string')
            end

            if ~ischar(serialComms)
                fprintf('Input argument "serialComms" to tiberius class should be a string\n')
                return
            end

            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end

            obj.maxWavelength=1100;
            obj.minWavelength=700;
            obj.friendlyName = 'tiberius';

            fprintf('\nSetting up tiberius laser communication on serial port %s\n', serialComms);
            obj.controllerID=serialComms;
            success = obj.connect;

            if ~success
                fprintf('Component tiberius failed to connect to laser over the serial port.\n')
                return
                %TODO: is it possible to delete it here?
            end

            %Set the target wavelength to equal the current wavelength
            obj.targetWavelength=obj.currentWavelength;

            %Report connection and humidity
            fprintf('Connected to Tiberius laser on %s\n\n', serialComms)

            % Must call these here to make sure Pockels is turned on
            obj.isPoweredOn;
            obj.isModeLocked;
            obj.switchPockelsCell;

            obj.startPollingSerialPort
        end % tiberius


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            % tiberius.delete
            %
            % Purpose
            % Destructor. Stops the timers (via laser.delete) and then closes the
            % serial connection to the laser.

            fprintf('Disconnecting from tiberius laser\n')
            delete@laser(obj);
            if ~isempty(obj.hC) && isvalid(obj.hC)
                fprintf('Closing serial communications with tiberius laser\n')
                flush(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                delete(obj.hC);
                delete(obj.hDO)
            end
        end % delete


        function success = connect(obj)
            % tiberius.connect
            %
            % Purpose
            % Open the serial port to the Tiberius and attach the async serial callback.
            %
            % Note: for detailed documentation see laser.connect

            try
                obj.hC=serialport(obj.controllerID,19200,'FlowControl','software','Timeout',5);
            catch ME
                fprintf(' * ERROR: Failed to connect to tiberius:\n%s\n\n', ME.message)
                success=false;
                obj.isLaserConnected=success;
                return
            end
            configureTerminator(obj.hC,"CR/LF")
            obj.setupAsyncSerial % attach the terminator callback + init the command queue

            flush(obj.hC) % Just in case
            if isempty(obj.hC)
                success=false;
            else
                % Retry the probe: a single lost reply must not condemn a laser which
                % is in fact there. See laser.verifyCommsWithLaser.
                success = obj.verifyCommsWithLaser(obj.CMD_QUERY_SHUTTER);
                if success
                    % Cache the shutter state now so the GUI shows it correctly as
                    % soon as it opens rather than only after the first poll.
                    obj.isShutterOpen;
                else
                    fprintf('Failed to communicate with tiberius laser\n');
                end
            end
            obj.isLaserConnected=success;
        end % connect


        function success = isControllerConnected(obj)
            % tiberius.isControllerConnected
            %
            % Purpose
            % Return true if we can communicate with the laser. Probes the shutter
            % state as the communication test.
            %
            % Note: for detailed documentation see laser.isControllerConnected

            if isempty(obj.hC) || ~isvalid(obj.hC)
                success=false;
            else
                [~,success] = obj.isShutterOpen;
            end
            obj.isLaserConnected=success;
        end % isControllerConnected


        function success = turnOn(obj)
            % tiberius.turnOn
            %
            % Purpose
            % Switch the laser on.
            %
            % Note: for detailed documentation see laser.turnOn

            fprintf('Trying to turn on Tiberius\n')

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            obj.sendAndReceiveSerial('LASER=1',false);
            obj.isLaserOn = true;
            success=true;
            obj.switchPockelsCell %Gate Pockels mains power
        end % turnOn


        function success = turnOff(obj)
            % tiberius.turnOff
            %
            % Purpose
            % Switch the laser off. Closes the shutter first because older Tiberius
            % lasers do not do this automatically.
            %
            % Note: for detailed documentation see laser.turnOff

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            obj.closeShutter; % Older tiberius lasers seem not to do this by default
            obj.sendAndReceiveSerial('LASER=0',false);
            obj.isLaserOn = false;
            success=true;
            obj.switchPockelsCell %Gate Pockels mains power
        end % turnOff


        function [powerOnState,details] = isPoweredOn(obj)
            % tiberius.isPoweredOn
            %
            % Purpose
            % Return the cached on/off state. The Tiberius has no serial query for the
            % power state, so this just returns isLaserOn (set by turnOn / turnOff).
            %
            % Note: for detailed documentation see laser.isPoweredOn

            powerOnState = obj.isLaserOn;
            details='';
        end % isPoweredOn


        function modelockState = isModeLocked(obj)
            % tiberius.isModeLocked
            %
            % Purpose
            % Returns true if the laser is modelocked. False otherwise.
            %
            % Note: for detailed documentation see laser.isModeLocked

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_MODELOCK);
            if ~success %If we can't talk to it, we assume it's also not modelocked (maybe questionable, but let's go with this for now)
                modelockState=0;
                obj.isLaserModeLocked=modelockState;
                return
            end

            obj.handleModelockReply(reply);
            modelockState=obj.isLaserModeLocked;
        end % isModeLocked

        function handleModelockReply(obj,reply)
            % tiberius.handleModelockReply
            %
            % Purpose
            % Parse the reply to a STATUS? query and cache the modelock state in
            % isLaserModeLocked. The laser returns "R" for modelocked and "N" for not.
            % Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            if strcmp(reply,'R')
                obj.isLaserModeLocked = true;
            elseif strcmp(reply,'N')
                obj.isLaserModeLocked = false;
            else
                fprintf('Unknown reply for modelock state: "%s"\n', reply)
                obj.isLaserModeLocked = false;
            end
        end % handleModelockReply


        function success = openShutter(obj)
            % tiberius.openShutter
            %
            % Purpose
            % Open the laser's shutter.
            %
            % Note: for detailed documentation see laser.openShutter

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('S=1',false);
            %%pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=true;
            end
        end % openShutter


        function success = closeShutter(obj)
            % tiberius.closeShutter
            %
            % Purpose
            % Close the laser's shutter.
            %
            % Note: for detailed documentation see laser.closeShutter

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('S=0',false);
            %%pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end % closeShutter


        function [shutterState,success] = isShutterOpen(obj)
            % tiberius.isShutterOpen
            %
            % Purpose
            % Return true if the shutter is open. Returns empty on a failed read.
            %
            % Note: for detailed documentation see laser.isShutterOpen

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_SHUTTER);
            if ~success
                shutterState=[];
                return
            end
            obj.handleShutterReply(reply);
            shutterState=obj.isLaserShutterOpen;
        end % isShutterOpen

        function handleShutterReply(obj,reply)
            % tiberius.handleShutterReply
            %
            % Purpose
            % Parse the reply to a shutter query (S?) and cache the state in
            % isLaserShutterOpen. The laser returns the state in the 3rd character
            % (1 = open). Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.isLaserShutterOpen = str2double(reply(3)); %if open the command returns 1
        end % handleShutterReply


        function wavelength = readWavelength(obj)
            % tiberius.readWavelength
            %
            % Purpose
            % Read the current wavelength in nm and cache it in currentWavelength.
            %
            % Note: for detailed documentation see laser.readWavelength

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_WAVELENGTH);
            if ~success
                wavelength=[];
                return
            end
            obj.handleWavelengthReply(reply);
            wavelength = obj.currentWavelength;
        end % readWavelength

        function handleWavelengthReply(obj,reply)
            % tiberius.handleWavelengthReply
            %
            % Purpose
            % Parse the reply to a wavelength query (W?) and cache the value in
            % currentWavelength. Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.currentWavelength = str2double(reply);
        end % handleWavelengthReply


        function success = setWavelength(obj,wavelengthInNM)
            % tiberius.setWavelength
            %
            % Purpose
            % Tune the laser to a new wavelength and start the fast tuning poll so the
            % GUI tracks the wavelength as it settles.
            %
            % Note: for detailed documentation see laser.setWavelength

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=false;
            if length(wavelengthInNM)>1
                fprintf('wavelength should be a scalar')
                return
            end
            if ~obj.isTargetWavelengthInRange(wavelengthInNM)
                return
            end
            cmd = sprintf('W=%d', round(wavelengthInNM));
            success=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            obj.targetWavelength=wavelengthInNM;

            % Poll the wavelength faster until the laser reaches the new setpoint.
            obj.startTuningPoll
        end % setWavelength


        function tuning = isTuning(obj)
            % tiberius.isTuning
            %
            % Purpose
            % Return true if the laser is still tuning towards its setpoint. Compares
            % the setpoint (W?) with the current wavelength.
            %
            % Note: for detailed documentation see laser.isTuning

            tuning=false; % Default: if we can't read, report "not tuning"

            %First get the desired (setpoint) wavelength
            [success,wavelengthDesired]=obj.sendAndReceiveSerial(obj.CMD_QUERY_WAVELENGTH);
            if ~success
                return
            end

            wavelengthDesired = str2double(wavelengthDesired(1:end));
            pause(0.33)
            currentWavelength = obj.readWavelength;

            if round(currentWavelength) == wavelengthDesired
                tuning=false;
            else
                tuning=true;
            end

        end % isTuning


        function laserPower = readPower(obj)
            % tiberius.readPower
            %
            % Purpose
            % The Tiberius has no serial command to read output power, so this returns
            % NaN and caches NaN in currentPower_mW.
            %
            % Note: for detailed documentation see laser.readPower

            laserPower = nan;
            obj.currentPower_mW = laserPower;
        end % readPower


        function laserID = readLaserID(~)
            % tiberius.readLaserID
            %
            % Purpose
            % Return the laser model string. The Tiberius has no command for detailed
            % identification info.
            %
            % Note: for detailed documentation see laser.readLaserID

            laserID = 'tiberius';
        end % readLaserID


        function laserStats = returnLaserStats(obj)
            % tiberius.returnLaserStats
            %
            % Purpose
            % Return a one-line string of laser status (wavelength, modelock state) for
            % logging during acquisition.
            %
            % Note: for detailed documentation see laser.returnLaserStats

            lambda = obj.readWavelength;
            modelockState = obj.isLaserModeLocked;
            if modelockState == true
                modelockState = 'yes';
            else
                modelockState = 'no';
            end

            laserStats=sprintf('wavelength=%dnm,modelocked=%s', ...
                lambda, modelockState);
        end % returnLaserStats


        function success=setWatchDogTimer(~,~)
            % tiberius.setWatchDogTimer
            %
            % Purpose
            % The Tiberius has no watchdog timer, so this does nothing and returns true.
            %
            % Note: for detailed documentation see laser.setWatchDogTimer

            success = true;
        end % setWatchDogTimer


        %%
        % Polling methods
        function readWavelengthDuringTuning(obj)
            % tiberius.readWavelengthDuringTuning
            %
            % Purpose
            % Override of laser.readWavelengthDuringTuning. Queues the wavelength read
            % (fire-and-forget) rather than blocking, so the tuning poll does not pump
            % the event queue while the laser tunes.
            %
            % Note: for detailed documentation see laser.readWavelengthDuringTuning

            obj.enqueueRead(obj.CMD_QUERY_WAVELENGTH, @obj.handleWavelengthReply);
        end % readWavelengthDuringTuning


        function pollSerial(obj)
            % tiberius.pollSerial
            %
            % Purpose
            % Override of laser.pollSerial. Queues the status reads (fire-and-forget)
            % and returns immediately, so the poller never spin-waits and hence never
            % pumps the event queue. Each reply is parsed by its handler in
            % asyncSerial.onSerialData. The Tiberius has no serial read for power or
            % on/off state, so only shutter, wavelength and modelock are polled.
            %
            % Note: for detailed documentation see laser.pollSerial

            % Recover if a previous fire-and-forget read stalled without a reply.
            obj.resyncStaleInFlight

            % Skip if a command is holding the poller off, or the previous burst hasn't
            % drained yet (don't pile reads onto the queue).
            if obj.pollPauseDepth > 0 || obj.serialInFlight || ~isempty(obj.cmdQueue)
                return
            end

            obj.enqueueRead(obj.CMD_QUERY_SHUTTER,    @obj.handleShutterReply);
            obj.enqueueRead(obj.CMD_QUERY_WAVELENGTH, @obj.handleWavelengthReply);
            obj.enqueueRead(obj.CMD_QUERY_MODELOCK,   @obj.handleModelockReply);
        end % pollSerial


    end %close methods

end %close classdef
