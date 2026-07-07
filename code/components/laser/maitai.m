classdef maitai < laser & loghandler
    %%  maitai - control class for maitai lasers
    %
    %
    % Example
    % M = maitai('COM1');
    %
    % Laser control component for MaiTai lasers from SpectraPhysics.
    % IMPORTANT: In the SpectraPhysics GUI you should set the baudrate
    % switch to "9600".
    %
    % maitai inherits the laser abstract class. For the API documentation (what each
    % of the shared methods is meant to do) see the doc text in laser.m. The methods
    % below that implement that API carry only a short note plus a pointer to the
    % matching laser method. Methods that are specific to the MaiTai (pump power,
    % humidity, warm-up state, error codes, the async reply handlers, etc.) carry
    % their own full doc text.
    %
    % Rob Campbell - Basel 2016
    %
    % Overhauled to handle async serial writes with serialport interface. Refactored.
    % Rob Campbell - SWC 2027

    properties (Hidden)
        % Implement a "grace period" between the pump power ramping up and down
        % and the user having issued a turn/on off
        powerCommandTime = NaT
        powerStateGraceSeconds = 20
    end

    properties (Constant, Hidden)
        % MaiTai serial commands — single-sourced so each string appears once
        CMD_QUERY_SHUTTER    = 'SHUTTER?'
        CMD_QUERY_STATEBITS   = '*STB?'
        CMD_QUERY_PUMP_POWER = 'READ:PLASER:POWER?'
        CMD_QUERY_POWER      = 'READ:POWER?'
        CMD_QUERY_WAVELENGTH = 'READ:WAVELENGTH?'
    end


    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = maitai(serialComms,logObject)
            % maitai
            %
            % Purpose
            % Constructor. Connect to a MaiTai laser on the specified serial port and
            % start the background status poller.
            %
            % Inputs
            % serialComms - [string] the serial port to connect to. e.g. 'COM1'
            % logObject   - [optional] a loghandler-derived object used for logging

            if nargin<1
                error('maitai requires at least one input argument: you must supply the laser COM port as a string')
            end

            if ~ischar(serialComms)
                error('Input argument "serialComms" to maitai class should be a string\n')
            end

            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end

            obj.maxWavelength=1100;
            obj.minWavelength=700;
            obj.friendlyName = 'MaiTai';

            fprintf('\nSetting up MaiTai laser communication on serial port %s\n', serialComms);
            obj.controllerID=serialComms;
            success = obj.connect;

            if ~success
                fprintf('Component maitai failed to connect to laser over the serial port.\n')
                return
            end

            %Set the target wavelength to equal the current wavelength
            obj.targetWavelength=obj.currentWavelength;

            %Report connection and humidity
            fprintf('Connected to SpectraPhysics laser on %s, laser humidity is %0.2f%%\n\n', ...
             serialComms, obj.readHumidity)


            % Must call these here to make sure Pockels is turned on
            obj.isPoweredOn;
            obj.isModeLocked;
            obj.switchPockelsCell;

            % Then force a power read and wavelength read before starting the polling
            obj.startPollingSerialPort;
        end % maitai


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            % maitai.delete
            %
            % Purpose
            % Destructor. Stops the timers (via laser.delete) and then closes the
            % serial connection to the laser.

            fprintf('Disconnecting from MaiTai laser\n')
            delete@laser(obj);
            if ~isempty(obj.hC) && isvalid(obj.hC)
                fprintf('Closing serial communications with MaiTai laser\n')
                flush(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                delete(obj.hC);
                delete(obj.hDO)
            end
        end % delete


        function success = connect(obj)
            % maitai.connect
            %
            % Purpose
            % Open the serial port to the MaiTai and attach the async serial callback.
            %
            % Note: for detailed documentation see laser.connect

            try
                obj.hC=serialport(obj.controllerID,9600,'Timeout',5);
            catch ME
                fprintf(' * ERROR: Failed to connect to MaiTai:\n%s\n\n', ME.message)
                success=false;
                obj.isLaserConnected=success;
                return
            end
            configureTerminator(obj.hC,"LF")
            obj.setupAsyncSerial % attach the terminator callback + init the command queue

            flush(obj.hC) % Just in case
            if isempty(obj.hC)
                success=false;
            else
                [~,s] = obj.isShutterOpen;
                if s==true
                    success=true;
                else
                    fprintf('Failed to communicate with maitai laser\n');
                    success=false;
                end
            end
            obj.isLaserConnected=success;
        end % connect


        function success = isControllerConnected(obj)
            % maitai.isControllerConnected
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



        %%
        % Turn on and turn off methods
        function success = turnOn(obj)
            % maitai.turnOn
            %
            % Purpose
            % Switch the laser on. Fails if the laser is not warmed up. Sets the
            % watchdog timer to zero so the laser stays on.
            %
            % Note: for detailed documentation see laser.turnOn

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            if obj.readWarmedUp<100
                fprintf('Laser is not warmed up. Current warm up state: %0.2f\n',obj.readWarmedUp)
                return
            end
            successA = obj.sendAndReceiveSerial('ON',false);
            successB = obj.setWatchDogTimer(0);  %otherwise it will turn off again
            success = successA & successB;
            if success
                obj.isLaserOn=true;
                obj.powerCommandTime = datetime('now'); % for grace period
                obj.turnOnPockelsCell %Gate Pockels mains power
            end

        end % turnOn


        function success = turnOff(obj)
            % maitai.turnOff
            %
            % Purpose
            % Switch the laser off. Closes the shutter first because older MaiTai
            % lasers do not do this automatically.
            %
            % Note: for detailed documentation see laser.turnOff

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            obj.closeShutter; % Older MaiTai lasers seem not to do this by default
            pause(0.25)
            success=obj.sendAndReceiveSerial('OFF',false);

            %TODO -- verify turn-off with a validated `readPumpPower` and report that.
            pause(0.25)

            % Force read of modelock state right away
            obj.isLaserModeLocked;

            if success
                obj.turnOffPockelsCell;
                obj.isLaserOn=false;
                obj.powerCommandTime = datetime('now'); % for grace period
            else
                fprintf('Reported laser still on\n')
            end

        end % turnOff


        function [powerOnState,details] = isPoweredOn(obj)
            % maitai.isPoweredOn
            %
            % Purpose
            % Return true if the laser is powered on. The state is derived from the
            % pump power (see readPumpPower); above powerOnThresh mW counts as on.
            %
            % Note: for detailed documentation see laser.isPoweredOn
            %
            % MaiTai specific: for powerStateGraceSeconds after a turnOn/turnOff the
            % commanded state is trusted rather than the (lagging) pump power reading.
            % This avoids the on/off indicator flickering while the pump ramps.

            % Bail out if we are within the grace period
            if ~isnat(obj.powerCommandTime) && ...
                    seconds(datetime('now') - obj.powerCommandTime) < obj.powerStateGraceSeconds
                powerOnState = obj.isLaserOn;   % trust the recent command; don't clobber
                details = 'within grace period';
                return
            end

            pPower=obj.readPumpPower;

            % Validate response (untested)
            if isempty(pPower) || isnan(pPower)
                powerOnState = obj.isLaserOn;
                details = 'read failed';
                return
            end

            powerOnThresh = 15;

            if pPower>powerOnThresh
                powerOnState=true;
            else
                powerOnState=false;
            end


            obj.isLaserOn=powerOnState;

            details=num2str(pPower);

        end % isPoweredOn


        %%
        % Shutter open ad close methods
        function success = openShutter(obj)
            % maitai.openShutter
            %
            % Purpose
            % Open the laser's internal shutter and gate the Pockels cell on.
            %
            % Note: for detailed documentation see laser.openShutter

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('SHUTTER 1',false);
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=obj.isShutterOpen;
            end

            % Add this here just in case the turn off/turn on commands behaved weirdly
            % and the Pockels cells is off
            pause(0.25)
            if obj.isLaserShutterOpen
                obj.switchPockelsCell %Gate Pockels mains power
            end
        end % openShutter


        function success = closeShutter(obj)
            % maitai.closeShutter
            %
            % Purpose
            % Close the laser's internal shutter.
            %
            % Note: for detailed documentation see laser.closeShutter

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('SHUTTER 0',false);
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end % closeShutter



        %%
        % Query methods with handlers for queuing commands.

        function laserPower = readPower(obj)
            % maitai.readPower
            %
            % Purpose
            % Read the laser output power in mW and cache it in currentPower_mW.
            %
            % Note: for detailed documentation see laser.readPower

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_POWER);
            if ~success
                laserPower=[];
                return
            end
            obj.handlePowerReply(reply);
            laserPower = obj.currentPower_mW;
        end % readPower

        function handlePowerReply(obj,reply)
            % maitai.handlePowerReply
            %
            % Purpose
            % Parse the reply to a CMD_QUERY_POWER query and cache the value in
            % currentPower_mW. Called synchronously by readPower and asynchronously
            % by the poll queue (see asyncSerial.onSerialData).
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.currentPower_mW = round(str2double(reply(1:end-1))*1E3);
        end % handlePowerReply


        function modelockState = isModeLocked(obj)
            % maitai.isModeLocked
            %
            % Purpose
            % Returns true if the laser is modelocked. False otherwise.
            %
            % Note: for detailed documentation see laser.isModeLocked

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_STATEBITS);
            if ~success %If we can't talk to it, we assume it's also not modelocked (maybe questionable, but let's go with this for now)
                modelockState=0;
                obj.isLaserModeLocked=modelockState;
                return
            end

            obj.handleModelockReply(reply);
            modelockState=obj.isLaserModeLocked;
        end % isModeLocked

        function handleModelockReply(obj,reply)
            % maitai.handleModelockReply
            %
            % Purpose
            % Parse the reply to a status-bits query (*STB?) and cache the modelock
            % state in isLaserModeLocked. The modelock state is the second bit of the
            % returned 8 bit number.
            %
            % Inputs
            % reply - the raw reply string from the laser

            bits = fliplr(dec2bin(str2double(reply),8));
            obj.isLaserModeLocked = strcmp(bits(2),'1');
        end % handleModelockReply


        function [shutterState,success] = isShutterOpen(obj)
            % maitai.isShutterOpen
            %
            % Purpose
            % Return true if the shutter is open. On a failed read returns the last
            % known state.
            %
            % Note: for detailed documentation see laser.isShutterOpen

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_SHUTTER );

            % If it fails to read, return whatever was the last state
            if ~success
                disp('Failed to read shutter state. Returning last known state')
                shutterState=obj.isLaserShutterOpen;
                return
            end
            obj.handleShutterReply(reply);
            shutterState=obj.isLaserShutterOpen;
        end % isShutterOpen

        function handleShutterReply(obj,reply)
            % maitai.handleShutterReply
            %
            % Purpose
            % Parse the reply to a CMD_QUERY_SHUTTER query and cache the shutter state
            % in isLaserShutterOpen (the laser returns 1 when the shutter is open).
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.isLaserShutterOpen = str2double(reply); %if open the command returns 1
        end % handleShutterReply


        function wavelength = readWavelength(obj)
            % maitai.readWavelength
            %
            % Purpose
            % Read the current laser wavelength in nm and cache it in currentWavelength.
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
            % maitai.handleWavelengthReply
            %
            % Purpose
            % Parse the reply to a CMD_QUERY_WAVELENGTH query and cache the value in
            % currentWavelength. The trailing "nm" unit is stripped.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.currentWavelength = str2double(reply(1:end-2));
        end % handleWavelengthReply



        %%
        % Methods associated with tuning the laser wavelength
        function success = setWavelength(obj,wavelengthInNM)
            % maitai.setWavelength
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
            cmd = sprintf('WAVELENGTH %d', round(wavelengthInNM));
            success=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            obj.targetWavelength=wavelengthInNM;

            % Poll the wavelength faster until the laser reaches the new setpoint.
            obj.startTuningPoll
        end % setWavelength


        function tuning = isTuning(obj)
            % maitai.isTuning
            %
            % Purpose
            % Return true if the laser is still tuning towards its setpoint. Compares
            % the setpoint (WAVELENGTH?) with the current wavelength.
            %
            % Note: for detailed documentation see laser.isTuning

            tuning=false; % Default: if we can't read, report "not tuning"

            %First get the desired (setpoint) wavelength
            [success,wavelengthDesired]=obj.sendAndReceiveSerial('WAVELENGTH?');
            if ~success
                return
            end

            wavelengthDesired = str2double(wavelengthDesired(1:end-2));
            pause(0.33)
            currentWavelength = obj.readWavelength;

            if round(currentWavelength) == wavelengthDesired
                tuning=false;
            else
                tuning=true;
            end

        end % isTuning


        %%
        % Other laser query methods
        function laserID = readLaserID(obj)
            % maitai.readLaserID
            %
            % Purpose
            % Return the laser identification string (*IDN? query).
            %
            % Note: for detailed documentation see laser.readLaserID

            [success,laserID]=obj.sendAndReceiveSerial('*IDN?');
            if ~success
                laserID=[];
                return
            end
        end % readLaserID


        function laserStats = returnLaserStats(obj)
            % maitai.returnLaserStats
            %
            % Purpose
            % Return a one-line string of laser status (wavelength, output power, pump
            % power, pump current, humidity) for logging during acquisition.
            %
            % Note: for detailed documentation see laser.returnLaserStats

            lambda = obj.readWavelength;
            outputPower = obj.readPower;
            pumpPower = obj.readPumpPower;
            pumpCurrent = obj.readPumpLaserCurrent;
            humidity = obj.readHumidity;

            laserStats=sprintf('wavelength=%dnm,outputPower=%dmW,pumpPower=%dmW,pumpCurrent=%0.1f,humidity=%0.1f', ...
                lambda,outputPower,pumpPower,pumpCurrent,humidity);
        end % returnLaserStats

        function success=setWatchDogTimer(obj,value)
            % maitai.setWatchDogTimer
            %
            % Purpose
            % Set the laser's communication watchdog time-out in seconds. Zero disables
            % it. The set value is read back to confirm it took.
            %
            % Note: for detailed documentation see laser.setWatchDogTimer

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);


            cmd=sprintf('TIMER:WATCHDOG %d',round(value));
            success=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            [success,currentValue]=obj.sendAndReceiveSerial('TIMER:WATCHDOG?');
            if ~success
                return
            end

            currentValue = round(str2double(currentValue));
            if currentValue ~= value
                fprintf('You asked for a MaiTai watchdog timer value %d seconds but the set value is reported as being %d seconds\n',...
                    value,currentValue)
                success=false;
            end
        end % setWatchDogTimer



        %%
        % Polling methods
        function readWavelengthDuringTuning(obj)
            % maitai.readWavelengthDuringTuning
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
            % maitai.pollSerial
            %
            % Purpose
            % Override of laser.pollSerial. Queues the status reads (fire-and-forget)
            % and returns immediately, so the poller never spin-waits and hence never
            % pumps the event queue. Each reply is parsed by its handler in
            % asyncSerial.onSerialData.
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
            obj.enqueueRead(obj.CMD_QUERY_PUMP_POWER, @obj.handlePumpPowerReply);
            obj.enqueueRead(obj.CMD_QUERY_POWER,      @obj.handlePowerReply);
            obj.enqueueRead(obj.CMD_QUERY_WAVELENGTH, @obj.handleWavelengthReply);
            obj.enqueueRead(obj.CMD_QUERY_STATEBITS,  @obj.handleModelockReply);
        end % pollSerial



        % MaiTai specific
        function laserPower = readPumpPower(obj)
            % maitai.readPumpPower
            %
            % Purpose
            % Return the pump laser power as a scalar in mW and cache it in
            % currentPumpPower_mW. MaiTai specific: used to infer the on/off state.
            %
            % Outputs
            % laserPower - pump power in mW. Empty if the read failed.

            [success,laserPower]=obj.sendAndReceiveSerial(obj.CMD_QUERY_PUMP_POWER);
            if ~success
                laserPower=[];
                return
            end
            laserPower = str2double(laserPower(1:end-1))*1E3;
            laserPower = round(laserPower);
            obj.currentPumpPower_mW = laserPower;
        end % readPumpPower

        function handlePumpPowerReply(obj,reply)
            % maitai.handlePumpPowerReply
            %
            % Purpose
            % Parse the reply to a pump-power query, cache it in currentPumpPower_mW,
            % and update the on/off state (isLaserOn) from it. Honours the grace period
            % after a turnOn/turnOff (see isPoweredOn). Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            pPower = round(str2double(reply(1:end-1))*1E3);
            obj.currentPumpPower_mW = pPower;

            % Within the grace period after a turn on/off, trust the command, don't clobber.
            if ~isnat(obj.powerCommandTime) && ...
                    seconds(datetime('now') - obj.powerCommandTime) < obj.powerStateGraceSeconds
                return
            end

            if isnan(pPower)
                return
            end

            obj.isLaserOn = pPower>15;
        end % handlePumpPowerReply


        function pLasI = readPumpLaserCurrent(obj)
            % maitai.readPumpLaserCurrent
            %
            % Purpose
            % Return the pump laser current as a scalar. MaiTai specific.
            %
            % Outputs
            % pLasI - pump laser current. Empty if the read failed.

            [success,pLasI]=obj.sendAndReceiveSerial('READ:PLASER:PCURRENT?');
            if ~success
                pLasI=[];
                return
            end
            pLasI = str2double(pLasI(1:end-1));
        end % readPumpLaserCurrent


        function laserHumidity = readHumidity(obj)
            % maitai.readHumidity
            %
            % Purpose
            % Return the laser head relative humidity as a percentage. MaiTai specific.
            %
            % Outputs
            % laserHumidity - humidity in %. Empty if the read failed.

            [success,laserHumidity]=obj.sendAndReceiveSerial('READ:HUM?');
            if ~success
                laserHumidity=[];
                return
            end
            laserHumidity = str2double(laserHumidity(1:end-3));
        end % readHumidity


        function warmedUpValue = readWarmedUp(obj)
            % maitai.readWarmedUp
            %
            % Purpose
            % Return a scalar describing how warmed up the laser is. 100 means fully
            % warmed up. Used by turnOn to block switch-on until the laser is ready.
            %
            % Outputs
            % warmedUpValue - percentage warmed up (100 = ready). Empty if nothing was
            %                 read back.

            [success,warmedUpValue]=obj.sendAndReceiveSerial('READ:PCTWarmedup?');
            if ~success
                warmedUpValue=[];
                return
            end
            warmedUpValue = str2double(warmedUpValue(1:end-1));
        end % readWarmedUp


        function emission = emissionPossible(obj)
            % maitai.emissionPossible
            %
            % Purpose
            % Return true if the laser is emitting. Read from the first bit of the
            % status-bits (*STB?) number. Used by the readiness check.
            %
            % Note: for detailed documentation see laser.emissionPossible

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_STATEBITS);
            if ~success %If we can't talk to it, we assume it's also not emitting (maybe questionable, but let's go with this for now)
                emission=false;
                return
            end

            %emission state is the first bit of the returned 8 bit number
            bits = fliplr(dec2bin(str2double(reply),8));
            if strcmp(bits(1),'1')
                emission=1;
            else
                emission=0;
            end
        end % emissionPossible


        function readErrorCodeHistory(obj)
            % maitai.readErrorCodeHistory
            %
            % Purpose
            % Print the MaiTai pump-laser error code history to the command line.
            % MaiTai specific. Diagnostic only; returns nothing.

            [success,reply]=obj.sendAndReceiveSerial('PLAS:AHIS?');
            disp(reply)

        end % readErrorCodeHistory


        function readLastErrorCode(obj)
            % maitai.readLastErrorCode
            %
            % Purpose
            % Print the MaiTai's most recent pump-laser error code to the command line.
            % MaiTai specific. Diagnostic only; returns nothing.

            [~,reply]=obj.sendAndReceiveSerial('PLAS:ERRC?');
            disp(reply)

        end % readLastErrorCode


    end %close methods

end %close classdef
