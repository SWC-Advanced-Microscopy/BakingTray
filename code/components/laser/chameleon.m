classdef chameleon < laser & loghandler
%%  chameleon - control class for Coherent Chameleon lasers
%
%
% Example
% C = chameleon('COM1');
%
% Laser control component for Chameleon lasers from Coherent.
% Tested with Chameleon Vision S
%
% chameleon inherits the laser abstract class. For the API documentation (what each
% of the shared methods is meant to do) see the doc text in laser.m. The methods
% below that implement that API carry only a short note plus a pointer to the
% matching laser method. Methods that are specific to the Chameleon (humidity,
% warm-up state, key switch, baseplate temperature, fault state, the async reply
% handlers, etc.) carry their own full doc text.
%
% Rob Campbell - Basel 2017

    properties (Constant,Hidden)
       % The following is a list of Chemeleon fault states taken from the
       % Chameleon Ultra and Chameleon Vision operatpr manual page 5-8.
       faultMessage = ...
            {'Laser head interlock', 'External interlock', ...
              'PS cover interlock', 'LBO temperature', ...
              'LBO not locked at set temperature', 'Vanadate temperature', ...
              'Etalon temperature', 'Diode 1 temperature', ...
              'Diode 2 temperature', 'Baseplate temperature', ...
              'Heatsink 1 temperature', 'Heatsink 2 temperature', ...
              '', '', '', ... %These are placeholders because there are gaps in the fault index numbers
              'Diode 1 over-current', 'Diode 2 over-current', ...
              'Over-current', 'Diode 1 under-voltage', ...
              'Diode 2 under-voltage', 'Diode 1 over-voltage', ...
              'Diode 2 over-voltage', '', '', 'Diode 1 EEPROM', ...
              'Diode 2 EEPROM', 'Laser head EEPROM', 'PS EEPROM',...
              'PS-head mismatch', 'LBO battery', 'Shutter state mismatch', ...
              'CPU PROM checksum', 'Head PROM checksum', ...
              'Diode 1 PROM checksum', 'Diode 2 PROM checksum', ...
              'CPU PROM range','Head PROM range', 'Diode 1PROM range', ...
              'Diode 2 PROM range', 'Head-diode mismatch', '', '', ...
              'Lost modelock', '', '', '', 'Ti-Sapph temperature', '', ...
              'PZT X', 'Cavity humidity', 'Tuning stepper motor homing', ...
              'Lasing', 'Laser failed to begin modelocking', 'Headboard comms', ...
              'System lasing', 'PS-head EEPROM mismatch', ...
              'Modelock slit stepper motor homing', 'Chameleon-verdi EEPROM', ...
              'Chameleon precompensator homing', 'Chameleon curve EEPROM'};

       % Chameleon serial queries — single-sourced so each string appears once. These
       % are the queries issued by the status poll (see pollSerial).
       CMD_QUERY_SHUTTER    = '?S'    % shutter state (1 = open)
       CMD_QUERY_POWERSTATE = '?L'    % laser on/off state (1 = on)
       CMD_QUERY_POWER      = '?UF'   % output power in mW
       CMD_QUERY_WAVELENGTH = '?VW'   % current wavelength in nm
       CMD_QUERY_MODELOCK   = '?MDLK' % modelock state (1 = modelocked, 2 = CW, 0 = off)
    end % close properties

    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = chameleon(serialComms,logObject)
            % chameleon
            %
            % Purpose
            % Constructor. Connect to a Chameleon laser on the specified serial port and
            % start the background status poller.
            %
            % Inputs
            % serialComms - [string] the serial port to connect to. e.g. 'COM1'
            % logObject   - [optional] a loghandler-derived object used for logging

            if nargin<1
                error('chameleon requires at least one input argument: you must supply the laser COM port as a string')
            end

            if ~ischar(serialComms)
                error('Input argument "serialComms" to chameleon class should be a string\n')
            end

            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end

            obj.maxWavelength=1100;
            obj.minWavelength=700;
            obj.friendlyName = 'Chameleon';

            fprintf('\nSetting up Chameleon laser communication on serial port %s\n', serialComms);
            obj.controllerID=serialComms;
            success = obj.connect;

            if ~success
                fprintf('Component chameleon failed to connect to laser over the serial port.\n')
                return
                %TODO: is it possible to delete it here?
            end

            %Set the target wavelength to equal the current wavelength
            obj.targetWavelength=obj.currentWavelength;

            %Report connection and humidity
            fprintf('Connected to Chameleon laser on serial port %s\n\n', serialComms)


            % Must call these here to make sure Pockels is turned on
            obj.isPoweredOn;
            obj.isModeLocked;
            obj.switchPockelsCell;

            obj.startPollingSerialPort
        end % chameleon


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            % chameleon.delete
            %
            % Purpose
            % Destructor. Stops the timers (via laser.delete) and then closes the
            % serial connection to the laser.

            fprintf('Disconnecting from Chameleon laser\n')
            delete@laser(obj);
            if ~isempty(obj.hC) && isvalid(obj.hC)
                fprintf('Closing serial communications with Chameleon laser\n')
                flush(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                delete(obj.hC);
                delete(obj.hDO)
            end
        end % delete


        function success = connect(obj)
            % chameleon.connect
            %
            % Purpose
            % Open the serial port to the Chameleon, attach the async serial callback,
            % and disable the laser's command echo and prompt so replies are clean.
            %
            % Note: for detailed documentation see laser.connect

            try
                obj.hC=serialport(obj.controllerID,19200,'Timeout',5);
            catch ME
                fprintf(' * ERROR: Failed to connect to Chameleon:\n%s\n\n', ME.message)
                success=false;
                obj.isLaserConnected=success;
                return
            end
            configureTerminator(obj.hC,"CR/LF")
            obj.setupAsyncSerial % attach the terminator callback + init the command queue

            flush(obj.hC) % Just in case
            success = false;
            if ~isempty(obj.hC)
                s1 = obj.sendAndReceiveSerial('ECHO=0');   % So we don't get back a copy of the command
                s2 = obj.sendAndReceiveSerial('PROMPT=0'); % So we don't get the "CHAMELEON> " text after each command is sent
                s3 = obj.setWatchDogTimer(0); % Ensure laser does not turn off if there inactivity on the serial port

                if s1==1 && s2==1 && s3==1
                    success=true;
                else
                    % One of the setup commands went unanswered. Before condemning the
                    % laser, retry a plain query: a single lost reply must not condemn a
                    % laser which is in fact there. See laser.verifyCommsWithLaser.
                    success = obj.verifyCommsWithLaser(obj.CMD_QUERY_SHUTTER);
                    if ~success
                        fprintf('Failed to communicate with Chameleon laser\n')
                    end
                end

                if success
                    % Cache the shutter state now so the GUI shows it correctly as
                    % soon as it opens rather than only after the first poll.
                    obj.isShutterOpen;
                end
            end

            obj.isLaserConnected=success;
        end % connect


        function success = isControllerConnected(obj)
            % chameleon.isControllerConnected
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
            % chameleon.turnOn
            %
            % Purpose
            % Switch the laser on. The Chameleon can only be turned on remotely if its
            % key switch is in the active position and there is no fault state.
            %
            % Note: for detailed documentation see laser.turnOn

            success=false;

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            if ~obj.readKeySwitch
                fprintf('Key switch is set to "STANDBY". Can not turn on Chameleon laser.\n')
                obj.isLaserOn=success;
                return
            end

            faultInd = obj.readFaultState;
            % If there is no fault state we attempt to turn on the laser
            if length(faultInd)==1 && faultInd==0
                success=obj.sendAndReceiveSerial('L=1');
            else
                % Otherwise the laser is not turned on and the
                % readFaultState method will automatically have printed
                % to screen the fault message. So nothing more to do.
            end

            obj.isLaserOn=success;
            if success
                obj.doMonitor=true; % See laser.doMonitor
            end
            obj.switchPockelsCell; %Gate Pockels mains power
        end % turnOn


        function success = turnOff(obj)
            % chameleon.turnOff
            %
            % Purpose
            % Switch the laser off (possible even with the key switch at "ENABLE") and
            % close the shutter, which the laser does not do automatically.
            %
            % Note: for detailed documentation see laser.turnOff

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('L=0');
            pause(0.25)

            obj.closeShutter; %Because it doesn't turn off the shutter automatically

            if success
                obj.isLaserOn=false;
                obj.doMonitor=false; % See laser.doMonitor
            end
            obj.switchPockelsCell %Gate Pockels mains power
        end % turnOff


        function [powerOnState,details] = isPoweredOn(obj)
            % chameleon.isPoweredOn
            %
            % Purpose
            % Return true if the laser is powered on. Read directly from the laser
            % (?L query), so there is no lag and no grace period is needed.
            %
            % Note: for detailed documentation see laser.isPoweredOn

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_POWERSTATE);
            if ~success
                powerOnState=0;
                details='read failed';
                return
            end

            obj.handlePowerStateReply(reply);
            powerOnState = obj.isLaserOn;
            details = reply;
        end % isPoweredOn

        function handlePowerStateReply(obj,reply)
            % chameleon.handlePowerStateReply
            %
            % Purpose
            % Parse the reply to a power-state query (?L) and cache the on/off state in
            % isLaserOn (the laser returns 1 when on). Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.isLaserOn = (str2double(reply)==1);
        end % handlePowerStateReply


        function modelockState = isModeLocked(obj)
            % chameleon.isModeLocked
            %
            % Purpose
            % Returns true if the laser is modelocked. False otherwise.
            %
            % Note: for detailed documentation see laser.isModeLocked

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_MODELOCK);
            if ~success %If we can't talk to it, we assume it's also not modelocked (maybe questionable, but let's go with this for now)
                modelockState=false;
                obj.isLaserModeLocked=modelockState;
                return
            end

            obj.handleModelockReply(reply);
            modelockState=obj.isLaserModeLocked;
        end % isModeLocked

        function handleModelockReply(obj,reply)
            % chameleon.handleModelockReply
            %
            % Purpose
            % Parse the reply to a modelock query (?MDLK) and cache the state in
            % isLaserModeLocked. The laser returns 1 for modelocked, 2 for CW and 0 for
            % off, so only 1 counts as modelocked. Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            modelockState = str2double(reply);
            obj.isLaserModeLocked = (modelockState==1); %Because it can equal 2 (CW) or 0 (Off)
        end % handleModelockReply


        function success = openShutter(obj)
            % chameleon.openShutter
            %
            % Purpose
            % Open the laser's shutter and gate the Pockels cell on.
            %
            % Note: for detailed documentation see laser.openShutter

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('SHUTTER=1');
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=true;
            end

            % Add this here just in case the turn off/turn on commands behaved weirdly and the Pockels cells is off
            obj.switchPockelsCell %Gate Pockels mains power
        end % openShutter


        function success = closeShutter(obj)
            % chameleon.closeShutter
            %
            % Purpose
            % Close the laser's shutter.
            %
            % Note: for detailed documentation see laser.closeShutter

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('SHUTTER=0');
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end % closeShutter


        function [shutterState,success] = isShutterOpen(obj)
            % chameleon.isShutterOpen
            %
            % Purpose
            % Return true if the shutter is open (?S query returns 1). Returns empty on
            % a failed read.
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
            % chameleon.handleShutterReply
            %
            % Purpose
            % Parse the reply to a shutter query (?S) and cache the state in
            % isLaserShutterOpen (the laser returns 1 when open). Called from the poll
            % queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.isLaserShutterOpen = str2double(reply); %if open the command returns 1
        end % handleShutterReply


        function wavelength = readWavelength(obj)
            % chameleon.readWavelength
            %
            % Purpose
            % Read the current wavelength in nm and cache it in currentWavelength. The
            % Chameleon returns a non-numeric value while tuning, in which case
            % currentWavelength is left unchanged.
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
            % chameleon.handleWavelengthReply
            %
            % Purpose
            % Parse the reply to a wavelength query (?VW) and cache the value in
            % currentWavelength. While the laser is tuning the reply is not numeric, so
            % currentWavelength is left unchanged. Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            wavelength = str2double(reply);
            if ~isnan(wavelength)
                obj.currentWavelength=wavelength;
            end
        end % handleWavelengthReply


        function success = setWavelength(obj,wavelengthInNM)
            % chameleon.setWavelength
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
            cmd = sprintf('WAVELENGTH=%d', round(wavelengthInNM));
            success=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            obj.targetWavelength=wavelengthInNM;

            % Poll the wavelength faster until the laser reaches the new setpoint.
            obj.startTuningPoll
        end % setWavelength


        function tuning = isTuning(obj)
            % chameleon.isTuning
            %
            % Purpose
            % Return true if the laser is currently tuning (?TS query returns > 0).
            %
            % Note: for detailed documentation see laser.isTuning

            [success,reply]=obj.sendAndReceiveSerial('?TS');
            if ~success
                tuning=nan;
                return
            end

            reply = str2double(reply);

            if reply>0
                tuning=true;
            else
               tuning=false;
            end

        end % isTuning


        function laserPower = readPower(obj)
            % chameleon.readPower
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
            % chameleon.handlePowerReply
            %
            % Purpose
            % Parse the reply to an output-power query (?UF) and cache it in
            % currentPower_mW. Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.currentPower_mW = round(str2double(reply));
        end % handlePowerReply


        function laserID = readLaserID(obj)
            % chameleon.readLaserID
            %
            % Purpose
            % Return the laser identification string (serial number, ?SN query).
            %
            % Note: for detailed documentation see laser.readLaserID

            [success,laserID]=obj.sendAndReceiveSerial('?SN');
            if ~success
                laserID=[];
                return
            end
            laserID = ['Chameleon, Serial Number: ', laserID];
        end % readLaserID


        function laserStats = returnLaserStats(obj)
            % chameleon.returnLaserStats
            %
            % Purpose
            % Return a one-line string of laser status (wavelength, output power,
            % humidity, baseplate temperature) for logging during acquisition.
            %
            % Note: for detailed documentation see laser.returnLaserStats

            lambda = obj.readWavelength;
            outputPower = obj.readPower;
            humidity = obj.readHumidity;
            basePlate = obj.readBaseplateTemp;
            laserStats=sprintf('wavelength=%dnm,outputPower=%dmW,humidity=%0.1f,baseplate temp=%0.3f', ...
                lambda,outputPower,humidity,basePlate);
        end % returnLaserStats


        function success=setWatchDogTimer(obj,value)
            % chameleon.setWatchDogTimer
            %
            % Purpose
            % Set the laser's heartbeat watchdog. Zero or less disables it (HB=0);
            % otherwise the watchdog is enabled (HB=1) and the time-out is set (HBR),
            % clamped to the laser's 1..100 second range.
            %
            % Note: for detailed documentation see laser.setWatchDogTimer

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            if value <= 0
                [success,~] = obj.sendAndReceiveSerial('HB=0');
                return
            else
                [success,~] = obj.sendAndReceiveSerial('HB=1');
                if ~success
                    return
                end
                if value>100
                    value=100;
                elseif value<1
                    value=1;
                end
                value = num2str(round(value));
                [success,~] = obj.sendAndReceiveSerial(['HBR=',value]);
            end
        end % setWatchDogTimer


        %%
        % Polling methods
        function readWavelengthDuringTuning(obj)
            % chameleon.readWavelengthDuringTuning
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
            % chameleon.pollSerial
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
            obj.enqueueRead(obj.CMD_QUERY_POWERSTATE, @obj.handlePowerStateReply);
            obj.enqueueRead(obj.CMD_QUERY_POWER,      @obj.handlePowerReply);
            obj.enqueueRead(obj.CMD_QUERY_WAVELENGTH, @obj.handleWavelengthReply);
            obj.enqueueRead(obj.CMD_QUERY_MODELOCK,   @obj.handleModelockReply);
        end % pollSerial


        % Chameleon specific
        function laserHumidity = readHumidity(obj)
            % chameleon.readHumidity
            %
            % Purpose
            % Return the laser relative humidity as a percentage (?RH query). Chameleon
            % specific. Some lasers lack the sensor and just return 0.
            %
            % Outputs
            % laserHumidity - humidity in %. Empty if the read failed.

            [success,laserHumidity]=obj.sendAndReceiveSerial('?RH');
            if ~success
                laserHumidity=[];
                return
            end
            laserHumidity = str2double(laserHumidity);
        end % readHumidity

        function warmedUpValue = readWarmedUp(obj)
            % chameleon.readWarmedUp
            %
            % Purpose
            % Return true if the laser is warmed up and ready to emit. Determined from
            % the operating status text (?ST query), which returns "Starting" or "OK".
            % Chameleon specific.
            %
            % Outputs
            % warmedUpValue - true if warmed up (status contains "OK"). Empty if the
            %                 read failed.

            [success,warmedUpValue]=obj.sendAndReceiveSerial('?ST');
            if ~success
                warmedUpValue=[];
                return
            end

            if strfind(warmedUpValue,'OK')
                warmedUpValue=true;
            else
                warmedUpValue=false;
            end
        end % readWarmedUp


        function keyState = readKeySwitch(obj)
            % chameleon.readKeySwitch
            %
            % Purpose
            % Return the key switch state (?K query). Chameleon specific. The laser can
            % only be turned on remotely when the key is in the enable position.
            %
            % Outputs
            % keyState - scalar key switch state. Empty if the read failed.

            [success,reply] = obj.sendAndReceiveSerial('?K');
            if ~success
                keyState=[];
                return
            end
            keyState = str2double(reply);
        end % readKeySwitch

        function baseplateTemp = readBaseplateTemp(obj)
            % chameleon.readBaseplateTemp
            %
            % Purpose
            % Return the laser baseplate temperature (?BT query). Chameleon specific.
            %
            % Outputs
            % baseplateTemp - baseplate temperature. Empty if the read failed.

            [success,reply] = obj.sendAndReceiveSerial('?BT');
            if ~success
                baseplateTemp=[];
                return
            end
            baseplateTemp = str2double(reply);
        end % readBaseplateTemp


        function [faultNumbers,faultStateString] = readFaultState(obj)
            % chameleon.readFaultState
            %
            % Purpose
            % Return the laser fault state(s) as integer code(s) and a human-readable
            % string, and print any faults to screen. Chameleon specific. Used by turnOn
            % to decide whether it is safe to switch the laser on.
            %
            % Outputs
            % faultNumbers     - array of fault code integers (0 means no fault). Empty
            %                    if the state could not be read.
            % faultStateString - a string describing the fault(s), or 'no faults'.

            [success,faultNumbers]=obj.sendAndReceiveSerial('?F');

            if ~success
                faultNumbers=[];
                faultStateString = '';
                return
            end

            % Multiple fault states are separated by the character "&" so
            % we make an array of fault state numbers
            faultNumbers = cellfun(@str2double, strsplit(faultNumbers, '&'));

            % If the laser returns "0" there is no current fault state
            if length(faultNumbers)==1 && faultNumbers(1) == 0
                faultStateString = 'no faults';
                return
            end

            % Build a cell array of laser fault messages
            faultMSG = cell(1,length(faultNumbers)); % Error strings will go here
            for ii=1:length(faultNumbers)
                if faultNumbers(ii) > length(obj.faultMessage) || isempty(obj.faultMessage{faultNumbers(ii)})
                    % The returned number has indexed an out of bounds message or a missing message
                    faultMSG{ii} = sprintf('Unknown fault state: %d. ', faultNumbers(ii));
                else
                    faultMSG{ii} = sprintf('Fault code %d: %s fault. ', ...
                        faultNumbers(ii), obj.faultMessage{faultNumbers(ii)});
                end
            end

            % Report these to screen and return as an output

            % Otherwise we have one or more faults. Report these:
            if length(faultNumbers) == 1
                fprintf('Laser reports 1 error:\n')
            elseif length(faultNumbers) > 1
                fprintf('Laser reports %d errors:\n', length(faultNumbers))
            end

            cellfun(@(x) fprintf('%s\n',x), faultMSG) % Display on CMD line

            faultStateString = [faultMSG{:}]; % Output of this method

        end % readFaultState

    end %close methods

end %close classdef
