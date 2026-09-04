classdef axon < laser & loghandler
%%  axon - control class for Coherent Axon lasers
%
%
% Example
% A = axon('COM1');
%
% Laser control component for Axon lasers from Coherent. The Axon is a single
% fixed-wavelength (780 / 920 / 1064 nm) femtosecond source that cannot be tuned.
% This class was written against an Axon TPC unit and tested with a Coherent Axon.
%
% axon inherits the laser abstract class. For the API documentation (what each of
% the shared methods is meant to do) see the doc text in laser.m. The methods below
% that implement that API carry only a short note plus a pointer to the matching
% laser method. Methods specific to the Axon (the async reply handlers, the hardware
% key read, the power-mode control, and the reply cleaner) carry their own full
% doc text.
%
% Notes on the Axon relative to the other lasers:
% * This is a single-wavelength (non-tunable) fibre laser. The laser does not return its
%   wavelength when queried so readWavelength returns a cached value and setWavelength
%   and isTuning do nothing. The cached value comes from the component settings file
%   (laser(n).wavelength) and is applied by buildLaserComponent as the laser is built. If
%   you build an axon at the command line you should do the same yourself:
%   A = axon('COM1');
%   A.setFixedWavelength(1064);
%   Otherwise the laser reports a wavelength of 0 nm. See axon.setFixedWavelength.
% * It has no software shutter (the head shutter is a manual lever). The shutter is
%   therefore always reported as open and openShutter / closeShutter do nothing.
% * On/off is done with the software key: SKEY=1 (on) and SKEY=0 (off). The hardware
%   key switch must be in the ENABLE position for SKEY=1 to take effect.
% * Replies are framed "<reply><ETX><CR><LF>". The terminator strips the CR/LF; the
%   trailing ETX (0x03) is removed locally by cleanReply.
%
%
% Rob Campbell - SWC 2026


    properties (Constant,Hidden)
        LASER_NAME = 'Axon' % Base of the friendlyName. setFixedWavelength appends the
                            % wavelength to this, e.g. "Axon-1064", since a system may
                            % have more than one Axon and only the wavelength tells
                            % them apart.
    end % close constant properties


    properties (Constant,Hidden)
        % Axon serial queries and commands — single-sourced so each string appears
        % once. The queries prefixed with the polled comment are issued by the status
        % poll (see pollSerial).
        CMD_QUERY_STATE    = '?STATE'    % operating state (LASING when emitting/pulsing) [polled]
        CMD_QUERY_POWER    = '?POWER'    % output power in mW [polled]
        CMD_QUERY_SOFTKEY  = '?SKEY'     % software key / enabled state (1 = enabled) [polled]
        CMD_QUERY_HARDKEY  = '?HKEY'     % hardware key switch (1 = active/ENABLE)
        CMD_ENABLE         = 'SKEY=1'    % enable (turn on) the laser
        CMD_DISABLE        = 'SKEY=0'    % disable (turn off) the laser
        CMD_FULL_POWER     = 'LPMODE=0'  % full (high) power mode
        CMD_ALIGNMENT_MODE = 'LPMODE=1'  % low power / alignment mode
        CMD_EXTERNAL_AOM   = 'AOM:EXT=1' % AOM follows the external analog modulation input (TPC)
    end % close constant properties


    properties (Hidden)
        inAlignmentMode = false % Cached: true when in low-power (alignment) mode. The
                                % Axon has no query to read LPMODE back, so we track it
                                % ourselves (set by switchToFullPower / switchToAlignmentMode).
    end % close hidden properties


    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = axon(serialComms,logObject)
            % axon
            %
            % Purpose
            % Constructor. Connect to an Axon laser on the specified serial port and
            % start the background status poller.
            %
            % Inputs
            % serialComms - [string] the serial port to connect to. e.g. 'COM1'
            % logObject   - [optional] a loghandler-derived object used for logging

            if nargin<1
                error('axon requires at least one input argument: you must supply the laser COM port as a string')
            end

            if ~ischar(serialComms)
                error('Input argument "serialComms" to axon class should be a string\n')
            end

            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end

            % The Axon is a single fixed-wavelength laser and cannot be tuned. There is no
            % serial query for the emitted wavelength, so these are placeholders only. The
            % real values are applied by setFixedWavelength, which buildLaserComponent calls
            % with laser(n).wavelength from the component settings file before this object is
            % handed to BT.attachLaser.
            obj.currentWavelength = 0;
            obj.friendlyName = obj.LASER_NAME;

            fprintf('\nSetting up Axon laser communication on serial port %s\n', serialComms);
            obj.controllerID=serialComms;
            success = obj.connect;

            if ~success
                fprintf('Component axon failed to connect to laser over the serial port.\n')
                return
            end

            % The Axon does not tune, so the target always equals the current wavelength
            obj.targetWavelength=obj.currentWavelength;

            fprintf('Connected to Axon laser on serial port %s\n\n', serialComms)

            % Populate the cached state (and gate Pockels power if configured)
            obj.isPoweredOn;
            obj.isModeLocked;
            obj.isShutterOpen;
            obj.switchPockelsCell;

            obj.startPollingSerialPort
        end % axon


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            % axon.delete
            %
            % Purpose
            % Destructor. Stops the timers (via laser.delete) and then closes the
            % serial connection to the laser.

            fprintf('Disconnecting from Axon laser\n')
            delete@laser(obj);
            if ~isempty(obj.hC) && isvalid(obj.hC)
                fprintf('Closing serial communications with Axon laser\n')
                flush(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                delete(obj.hC);
                delete(obj.hDO)
            end
        end % delete


        function success = connect(obj)
            % axon.connect
            %
            % Purpose
            % Open the serial port to the Axon, attach the async serial callback,
            % disable the command echo and prompt, put the AOM under external analog
            % control, and switch the laser to full power.
            %
            % Note: for detailed documentation see laser.connect

            try
                obj.hC=serialport(obj.controllerID,115200,'Timeout',5);
            catch ME
                fprintf(' * ERROR: Failed to connect to Axon:\n%s\n\n', ME.message)
                success=false;
                obj.isLaserConnected=success;
                return
            end
            configureTerminator(obj.hC,"CR/LF")
            obj.setupAsyncSerial % attach the terminator callback + init the command queue

            flush(obj.hC) % Just in case
            success = false;
            if ~isempty(obj.hC)
                s1 = obj.sendAndReceiveSerial('ECHO=0');   % So replies are not prefixed with an echo of the command
                s2 = obj.sendAndReceiveSerial('PROMPT=0'); % So replies are not prefixed with the "AXON> " prompt

                % Configure for BakingTray use: the TPC AOM follows the external analog
                % modulation input (so power is set from the analog input), and the
                % laser runs at full power rather than low-power alignment mode.
                s3 = obj.sendAndReceiveSerial(obj.CMD_EXTERNAL_AOM);
                if ~s3
                    fprintf('Warning: Axon did not accept "%s" (external AOM control). Is this a TPC unit?\n', obj.CMD_EXTERNAL_AOM)
                end
                obj.switchToFullPower;

                if s1==1 && s2==1
                    success=true;
                else
                    % One of the setup commands went unanswered. Before condemning the
                    % laser, retry a plain query: a single lost reply must not condemn a
                    % laser which is in fact there. See laser.verifyCommsWithLaser.
                    success = obj.verifyCommsWithLaser(obj.CMD_QUERY_STATE);
                    if ~success
                        fprintf('Failed to communicate with Axon laser\n')
                    end
                end
            end

            obj.isLaserConnected=success;
        end % connect


        function success = isControllerConnected(obj)
            % axon.isControllerConnected
            %
            % Purpose
            % Return true if we can communicate with the laser. Probes the operating
            % state as the communication test.
            %
            % Note: for detailed documentation see laser.isControllerConnected

            if isempty(obj.hC) || ~isvalid(obj.hC)
                success=false;
            else
                [success,~] = obj.sendAndReceiveSerial(obj.CMD_QUERY_STATE);
            end
            obj.isLaserConnected=success;
        end % isControllerConnected


        function success = turnOn(obj)
            % axon.turnOn
            %
            % Purpose
            % Switch the laser on (SKEY=1). This only takes effect if the hardware key
            % switch is in the ENABLE position, so that is checked first.
            %
            % Note: for detailed documentation see laser.turnOn

            success=false;

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            if obj.readHardwareKey ~= 1
                fprintf('Axon hardware key switch is not in the ENABLE position. Can not turn on the laser.\n')
                obj.isLaserOn=success;
                return
            end

            success=obj.sendAndReceiveSerial(obj.CMD_ENABLE);
            obj.isLaserOn=success;
            if success
                obj.doMonitor=true; % See laser.doMonitor
            end
            obj.switchPockelsCell; %Gate Pockels mains power
        end % turnOn


        function success = turnOff(obj)
            % axon.turnOff
            %
            % Purpose
            % Switch the laser off (SKEY=0).
            %
            % Note: for detailed documentation see laser.turnOff

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial(obj.CMD_DISABLE);
            if success
                obj.isLaserOn=false;
                obj.doMonitor=false; % See laser.doMonitor
            end
            obj.switchPockelsCell %Gate Pockels mains power
        end % turnOff


        function [powerOnState,details] = isPoweredOn(obj)
            % axon.isPoweredOn
            %
            % Purpose
            % Return true if the laser is powered on. Read directly from the software
            % key state (?SKEY query), which is 1 when the laser is enabled.
            %
            % Note: for detailed documentation see laser.isPoweredOn

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_SOFTKEY);
            if ~success
                powerOnState=0;
                details='read failed';
                return
            end

            obj.handleSoftKeyReply(reply);
            powerOnState = obj.isLaserOn;
            details = reply;
        end % isPoweredOn

        function handleSoftKeyReply(obj,reply)
            % axon.handleSoftKeyReply
            %
            % Purpose
            % Parse the reply to a software-key query (?SKEY) and cache the on/off state
            % in isLaserOn (the laser returns 1 when enabled). Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            obj.isLaserOn = (str2double(obj.cleanReply(reply))==1);
        end % handleSoftKeyReply


        function modelockState = isModeLocked(obj)
            % axon.isModeLocked
            %
            % Purpose
            % Returns true if the laser is emitting (modelocked). The Axon has no
            % separate modelock query, so the operating state (?STATE = LASING) is used.
            %
            % Note: for detailed documentation see laser.isModeLocked

            [success,reply]=obj.sendAndReceiveSerial(obj.CMD_QUERY_STATE);
            if ~success %If we can't talk to it, we assume it's also not lasing
                modelockState=false;
                obj.isLaserModeLocked=modelockState;
                return
            end

            obj.handleStateReply(reply);
            modelockState=obj.isLaserModeLocked;
        end % isModeLocked

        function handleStateReply(obj,reply)
            % axon.handleStateReply
            %
            % Purpose
            % Parse the reply to an operating-state query (?STATE) and cache the result
            % in isLaserModeLocked. The Axon reports "LASING" when it is emitting pulses,
            % which is the closest equivalent to modelocked. Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            state = obj.cleanReply(reply);
            obj.isLaserModeLocked = strcmpi(state,'LASING');
        end % handleStateReply


        function success = openShutter(obj)
            % axon.openShutter
            %
            % Purpose
            % The Axon has no software shutter (the head shutter is a manual lever), so
            % this does nothing except report the shutter as open.
            %
            % Note: for detailed documentation see laser.openShutter

            obj.isLaserShutterOpen=true;
            success=true;
        end % openShutter


        function success = closeShutter(obj)
            % axon.closeShutter
            %
            % Purpose
            % The Axon has no software shutter, so this does nothing. The shutter is
            % always reported as open.
            %
            % Note: for detailed documentation see laser.closeShutter

            obj.isLaserShutterOpen=true;
            success=true;
        end % closeShutter


        function [shutterState,success] = isShutterOpen(obj)
            % axon.isShutterOpen
            %
            % Purpose
            % The Axon has no software shutter, so this always reports the shutter as
            % open. There is no serial round-trip.
            %
            % Note: for detailed documentation see laser.isShutterOpen

            obj.isLaserShutterOpen=true;
            shutterState=true;
            success=true;
        end % isShutterOpen


        function wavelength = readWavelength(obj)
            % axon.readWavelength
            %
            % Purpose
            % Return the (fixed) wavelength in nm. The Axon is single-wavelength and has
            % no serial query for it, so the cached currentWavelength is returned.
            %
            % Note: for detailed documentation see laser.readWavelength

            wavelength = obj.currentWavelength;
        end % readWavelength


        function success = setWavelength(obj,wavelengthInNM)
            % axon.setWavelength
            %
            % Purpose
            % The Axon is single-wavelength and cannot be tuned. Requesting the current
            % wavelength succeeds; any other value is rejected with a message.
            %
            % Note: for detailed documentation see laser.setWavelength

            if round(wavelengthInNM)==round(obj.currentWavelength)
                success=true;
                return
            end

            fprintf('The Axon is a single-wavelength laser and can not be tuned to %d nm. It stays at %d nm.\n', ...
                round(wavelengthInNM), round(obj.currentWavelength))
            success=false;
        end % setWavelength


        function tuning = isTuning(~)
            % axon.isTuning
            %
            % Purpose
            % The Axon is single-wavelength and never tunes, so this always returns false.
            %
            % Note: for detailed documentation see laser.isTuning

            tuning=false;
        end % isTuning


        function laserPower = readPower(obj)
            % axon.readPower
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
            % axon.handlePowerReply
            %
            % Purpose
            % Parse the reply to an output-power query (?POWER) and cache it in
            % currentPower_mW. Called from the poll queue.
            %
            % Inputs
            % reply - the raw reply string from the laser

            val = str2double(obj.cleanReply(reply));
            if ~isnan(val)
                obj.currentPower_mW = round(val);
            end
        end % handlePowerReply


        function laserID = readLaserID(obj)
            % axon.readLaserID
            %
            % Purpose
            % Return the laser identification string (serial number, ?SYS:SN query).
            %
            % Note: for detailed documentation see laser.readLaserID

            [success,serialNum]=obj.sendAndReceiveSerial('?SYS:SN');
            if ~success
                laserID=[];
                return
            end
            laserID = ['Coherent Axon, Serial Number: ', obj.cleanReply(serialNum)];
        end % readLaserID


        function laserStats = returnLaserStats(obj)
            % axon.returnLaserStats
            %
            % Purpose
            % Return a one-line string of laser status (wavelength, output power, state)
            % for logging during acquisition.
            %
            % Note: for detailed documentation see laser.returnLaserStats

            lambda = obj.readWavelength;
            outputPower = obj.readPower;
            obj.isModeLocked;
            if obj.isLaserModeLocked
                state='lasing';
            else
                state='not lasing';
            end
            laserStats=sprintf('wavelength=%dnm,outputPower=%dmW,state=%s', ...
                lambda, outputPower, state);
        end % returnLaserStats


        function success=setWatchDogTimer(~,~)
            % axon.setWatchDogTimer
            %
            % Purpose
            % The Axon has no serial watchdog timer, so this does nothing and returns true.
            %
            % Note: for detailed documentation see laser.setWatchDogTimer

            success = true;
        end % setWatchDogTimer


        % Axon specific
        function success = setFixedWavelength(obj,wavelengthInNM)
            % axon.setFixedWavelength
            %
            % Purpose
            % Tell the class what wavelength this Axon emits. Axon specific. The Axon is
            % a single fixed-wavelength laser (780 / 920 / 1064 nm) with no serial query
            % for the emitted wavelength, so the value has to be stated in the component
            % settings file:
            %   laser(n).wavelength=1064;
            % buildLaserComponent applies it as the laser is built. If it is never applied
            % the laser reports 0 nm in the GUI, in the acquisition log, and in
            % returnLaserStats.
            %
            % The friendlyName is updated at the same time (e.g. "Axon-1064") because a
            % system may have more than one Axon and the wavelength is what tells them
            % apart in the GUI title and the log messages.
            %
            % Inputs
            % wavelengthInNM - [scalar] the wavelength this laser emits, in nm.
            %
            % Outputs
            % success - true if the wavelength was applied. If it was not, the laser is
            %           left exactly as it was and a message explains why.

            success=false;

            if nargin<2 || isempty(wavelengthInNM)
                fprintf(['\n ** The wavelength of this %s is not defined, so it will report %d nm.\n', ...
                    '    Add "laser(n).wavelength=1064;" (or whatever your model emits) to your\n', ...
                    '    component settings file.\n\n'], obj.LASER_NAME, round(obj.currentWavelength))
                return
            end

            % Sanity check rather than a model check: the Axon comes at 780, 920, or 1064 nm
            % but we do not want to refuse a model we have not heard of.
            if ~isnumeric(wavelengthInNM) || ~isscalar(wavelengthInNM) || ...
                wavelengthInNM<600 || wavelengthInNM>1400
                fprintf(['\n ** "%s" is not a plausible wavelength in nm for a %s. Ignoring it.\n', ...
                    '    This %s will report %d nm.\n\n'], ...
                    mat2str(wavelengthInNM), obj.LASER_NAME, obj.LASER_NAME, round(obj.currentWavelength))
                return
            end

            obj.currentWavelength = round(wavelengthInNM);
            obj.targetWavelength = obj.currentWavelength; % The Axon does not tune
            obj.friendlyName = sprintf('%s-%d', obj.LASER_NAME, obj.currentWavelength);
            success=true;
        end % setFixedWavelength


        function keyState = readHardwareKey(obj)
            % axon.readHardwareKey
            %
            % Purpose
            % Return the state of the physical hardware key switch (?HKEY query). Axon
            % specific. The laser can only be enabled (SKEY=1) when this is 1 (the key
            % is in the ENABLE position). Used by turnOn.
            %
            % Outputs
            % keyState - 1 if the hardware key is active, 0 otherwise. Empty on a failed read.

            [success,reply] = obj.sendAndReceiveSerial(obj.CMD_QUERY_HARDKEY);
            if ~success
                keyState=[];
                return
            end
            keyState = str2double(obj.cleanReply(reply));
        end % readHardwareKey


        function success = switchToFullPower(obj)
            % axon.switchToFullPower
            %
            % Purpose
            % Switch the laser to full (high) power mode (LPMODE=0). Axon specific. This
            % is the normal imaging mode and is set automatically at connect time.
            %
            % Outputs
            % success - true if the command was acknowledged

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success = obj.sendAndReceiveSerial(obj.CMD_FULL_POWER);
            if success
                obj.inAlignmentMode = false;
            end
        end % switchToFullPower


        function success = switchToAlignmentMode(obj)
            % axon.switchToAlignmentMode
            %
            % Purpose
            % Switch the laser to low-power alignment mode (LPMODE=1). Axon specific.
            % Intended for aligning the beam to the sample at reduced power.
            %
            % Outputs
            % success - true if the command was acknowledged

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success = obj.sendAndReceiveSerial(obj.CMD_ALIGNMENT_MODE);
            if success
                obj.inAlignmentMode = true;
            end
        end % switchToAlignmentMode


        function powerMode = reportPowerMode(obj)
            % axon.reportPowerMode
            %
            % Purpose
            % Report whether the laser is in low-power alignment mode or full power mode.
            % Axon specific. The Axon has no query to read LPMODE back, so this reflects
            % the last mode set via switchToFullPower / switchToAlignmentMode (see the
            % inAlignmentMode property).
            %
            % Outputs
            % powerMode - the string 'alignment' or 'full power'

            if obj.inAlignmentMode
                powerMode = 'alignment';
            else
                powerMode = 'full power';
            end
        end % reportPowerMode


        function reply = cleanReply(~,reply)
            % axon.cleanReply
            %
            % Purpose
            % Tidy a raw Axon reply. Axon single-line replies are framed
            % "<reply><ETX><CR><LF>"; the CR/LF is consumed by the terminator, but the
            % trailing ETX (0x03) remains and would make str2double return NaN. This
            % strips the ETX and any surrounding whitespace (e.g. a leading TAB left by
            % an echoed command). Axon specific.
            %
            % Inputs
            % reply - the raw reply string
            %
            % Outputs
            % reply - the cleaned reply string

            reply = strrep(reply, char(3), ''); % remove ETX
            reply = strtrim(reply);
        end % cleanReply


        %%
        % Polling methods
        function pollSerial(obj)
            % axon.pollSerial
            %
            % Purpose
            % Override of laser.pollSerial. Queues the status reads (fire-and-forget)
            % and returns immediately, so the poller never spin-waits and hence never
            % pumps the event queue. Each reply is parsed by its handler in
            % asyncSerial.onSerialData. The Axon polls the software-key (on/off) state,
            % the operating state (lasing) and the output power; the shutter is virtual
            % and the wavelength is fixed, so neither is polled.
            %
            % Note: for detailed documentation see laser.pollSerial

            % Recover if a previous fire-and-forget read stalled without a reply.
            obj.resyncStaleInFlight

            % Skip if a command is holding the poller off, or the previous burst hasn't
            % drained yet (don't pile reads onto the queue).
            if obj.pollPauseDepth > 0 || obj.serialInFlight || ~isempty(obj.cmdQueue)
                return
            end

            obj.enqueueRead(obj.CMD_QUERY_SOFTKEY, @obj.handleSoftKeyReply);
            obj.enqueueRead(obj.CMD_QUERY_STATE,   @obj.handleStateReply);
            obj.enqueueRead(obj.CMD_QUERY_POWER,   @obj.handlePowerReply);
        end % pollSerial


    end %close methods

end %close classdef
