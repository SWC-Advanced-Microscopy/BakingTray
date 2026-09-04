classdef (Abstract) laser < BakingTray.asyncSerial
%%  laser
%
% The laser abstract class is a software entity that represents the physical
% laser that is used to scan the sample.
%
% The laser abstract class declares methods and properties that are used by the
% BakingTray class to check the laser state (Is the laser modelocked? Is it switched
% on?). The user also interacts with the laser to set and check wavelength and to
% change the shutter state, etc. Classes the control the laser must inherit laser.
% Objects that inherit laser are "attached" to instances of BakingTray using
% BakingTray.attachLaser. This method adds an instance of a class that inherits
% laser to the BakingTray.laser property.
%
% An example of a class that inherits laser is "maitai".
%
% Rob Campbell - Basel 2016
%
% Overhauled to handle async serial writes with serialport interface. Refactored.
% Rob Campbell - SWC 2027



    properties

        controllerID % The information required by the method that connects to the
                     % the controller at connect-time. This can be specified in whatever
                     % way is most suitable for the hardware at hand.
                     % e.g. COM port ID string
        maxWavelength=0 %The longest wavelength the laser can be tuned to in nm
        minWavelength=0 %The shortest wavelength the laser can be tuned to in nm

        % A cell array of wavelengths that are not allowed. Use if the laser has problems
        % in certain ranges. Can be defined in the startup_bt.m file which you can place in your
        % BakingTray SETTINGS folder.
        % Each cell defines the minimum and maximum the wavelengths that are not allowed.
        % The property is used in laser.bannedWavelengths
        % e.g. = {[916,925],[775,790]}
        % See the laser hardware setup in the on-line docs for more information.
        bannedWavelengths = {};

        friendlyName = '' % This string is displayed in the GUI window title. Shouldn't be too long. e.g. could be "MaiTai"
                          % This property is generally filled in by the class which inherits laser.
        beamName = '' % This string must correspond to the beam name in ScanImage. This is the string in the widget toolbar.
                      % The beamName property is only necessary if there are multiple beams in the system. This property
                      % needs to be set via the component settings file as it will differ between rigs.

        % The following is used for optional Pockels cell control. An external device
        % may be connected to Pockels cell power to turn the mains power on and off
        % with the laser
        doPockelsPowerControl=false %If true we attempt to gate pockels power with the DAQ
        pockelsDAQ='' % DAQ device ID for gating pockels power. e.g. "Dev1"
        pockelsDigitalLine='' % e.g. 'port0/line2' DO line for pockels cell.
        hDO % Handle to the digital output task
        pollPeriodInSeconds % will be set to defaultPollPeriodInSeconds

    end %close public properties

    properties (Hidden)
        parent % A reference of the parent object (likely the "hBT" BakingTray object)
               % to which this component is attached
        pollTimer % Handles regular serial reads
        defaultPollPeriodInSeconds = 1.5 % Serial port polling interval
        pollPauseDepth = 0  % >0 while a command is running; pollSerial skips
        tuningPollTimer % Polls the wavelength faster while the laser is tuning
    end % close hidden properties


    % These are GUI-related properties. The view class that comprises the GUI listens to changes in these
    % properties to know when to update the GUI. It is therefore necessary for these to be updated as
    % appropriate by classes which inherit laser. e.g. If the shutter is opened then the shutterOpen
    % property must be set to true. Failing to do this will cause the GUI to fail to update. All
    % properties in this section should be updated in the constructor once the laser is connected.
    % This class implements a serial port poller to handle this. Polling does not need to be done
    % by the GUI.
    properties (SetObservable, AbortSet)
        isLaserOn=false          % Must be updated by turnOn, turnOff, and isPoweredOn
        isLaserShutterOpen=false % True if open. Must be updated by closeShutter, openShutter, and isShutterOpen
        isLaserConnected=false   % Set by isControllerConnected
        currentPower_mW = 0      % Last read output power in mW. Must be updated by readPower (and the poller)
        currentPumpPower_mW = 0  % Last read pump power in mW. Not all lasers have this. Not critical.
        isLaserModeLocked=false  % Must be updated by isModeLocked
        isLaserReady=false       % Must be updated by isReady
        currentWavelength=-1     % This must be updated whenever readWavelength runs
        targetWavelength=0       % Must be updated by setWavelength

        % True if this laser takes part in the current acquisition. A monitored laser has its
        % modelock checked and will block or stop an acquisition if it is not ready. A laser with
        % doMonitor false is never modelock-checked and never blocks acquisition, but is still
        % given a watchdog and is still turned off when acquisition finishes.
        %
        % The flag follows the last deliberate switching of the laser: turnOn sets it true and
        % turnOff sets it false, in both cases only if the command succeeded.
        %
        % Default true, so a laser is monitored until someone switches it off through
        % BakingTray. Single-laser systems behave as they always have.
        doMonitor=true
    end %close GUI-related properties


    % The following are all critical methods that your class should define
    % You should also define a suitable destructor to clean up after you class
    methods (Abstract)
        success = connect(obj)
        % connect
        %
        % Behavior
        % Establishes a connection between the hardware device and the host PC.
        % The method uses the controllerID property to establish the connection.
        %
        % Outputs
        % success - true or false depending on whether a connection was established


        success = isControllerConnected(obj)
        % isControllerConnected
        %
        % Behavior
        % Reports whether the link to the laser is functional. This method must update
        % the hidden property isLaserConnected. If the interface, e.g. the COM port
        % is closed, the function must return false.
        %
        % Outputs
        % success - true or false depending on whether a working connection is present
        %           with the physical laser device (or whatever device controls it).
        %           i.e. it is not sufficient that, say, a COM port is open. For success
        %           to be true, the laser must prove that it can interact in some way
        %           with the host PC.


        success = turnOn(obj)
        % turnOn
        %
        % Behavior
        % This is a general-purpose "switch on" command. Most lasers will need to be
        % turned on in some way or have a software safety interlock disabled. This
        % method should do those things. High power 2-photon lasers tend to have a
        % built-in physical shutter. This method should not open this if possible.
        % Use the openShutter method for this purpose. Must update the hidden
        % property isLaserOn.
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        success = turnOff(obj)
        % turnOff
        %
        % Behavior
        % This is a general-purpose "switch off" command. Most lasers will need to be
        % turned off in some way or have a software safety interlock enabled once they are
        % no longer in use. This method is designed to do those things. This method
        % may or may not close the shutter. This is not important because many lasers
        % will automatically close it when they are turned off. Must update the hidden
        % property isLaserOn.
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded

        [powerOnState,details] = isPoweredOn(obj)
        % isPoweredOn
        %
        % Behavior
        % This function returns true if the laser is powered on or is in the process of
        % powering up. Some lasers will need to warm up for a period of time. The warm
        % up period is classified as powered on. This method must update the observable
        % property isLaserOn.
        %
        % Outputs
        % powerOnState - true/false. If powered on, set to true.
        % details - optional second argument containing a string with further information


        modelockState = isModeLocked(obj)
        % isModeLocked
        %
        % Behavior
        % Returns true if the laser is currently modelocked. Returns false otherwise.
        % Updates the hidden property isLaserModeLocked.
        %
        % Outputs
        % modelockState - true/false depending on whether the laser is modelocked


        success = openShutter(obj)
        % openShutter
        %
        % Behavior
        % Running this method should open the laser's built in shutter and return
        % true if the shutter state is now open. This method should use the isShutterOpen
        % method to achieve this. Updates the hidden property isLaserShutterOpen.
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        success = closeShutter(obj)
        % closeShutter
        %
        % Behavior
        % Running this method should close the laser's built in shutter and return
        % true if the shutter state is now closed. This method should use the isShutterOpen
        % method to achieve this. Updates the hidden property isLaserShutterOpen.
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        shutterState = isShutterOpen(obj)
        % isShutterOpen
        %
        % Behavior
        % Running this method should return true if the laser shutter is open and false otherwise.
        % Returns empty if the shutter state could not be read.  Updates the hidden property isLaserShutterOpen.
        %
        % Outputs
        % shutterState - true or false depending on whether the shutter is open or not


        wavelength = readWavelength(obj)
        % readWavelength
        %
        % Behavior
        % Reads the currently set wavelength of the laser and returns the value as a
        % scalar in nm. Updates the observable property currentWavelength on a
        % successful read. Returns empty if the read fails, in which case
        % currentWavelength is left unchanged.
        %
        % Outputs
        % wavelength - a scalar defining the laser's current wavelength in nm.


        success = setWavelength(obj, wavelengthInNM)
        % setWavelength
        %
        % Behavior
        % Sets the laser to a new wavelength and updates hidden property targetWavelength
        %
        % Inputs
        % wavelengthInNM - scalar defining wavelength in nm
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        tuning = isTuning(obj)
        % isTuning
        %
        % Behavior
        % Returns true if the laser is currently tuning to a new wavelength.
        % Returns false if the laser is at it's set wavelength.
        %
        %
        % Outputs
        % tuning - true/false depending on whether the laser is currently tuning


        laserPower = readPower(obj)
        % readPower
        %
        % Behavior
        % Reads the current laser power and returns the value as a scalar integer in mW.
        % It should discard the decimal point. Returns zero if the laser is switched off.
        % Returns empty if it fails. It should write to the observable property "currentPower_mW"
        %
        %
        % Outputs
        % laserPower - a scalar defining the laser's current power in mW.

        success = setWatchDogTimer(obj,timeInSeconds)
        % setWatchDogTimer
        %
        % Behavior
        % The laser's watchdog timer (present on MaiTai lasers, for instance) causes
        % the laser switch off if it has not communicated with the PC for a given
        % period of time. BakingTray uses this setting to automatically power off
        % the laser should acquisition have stopped in an unexpected way. For example,
        % a hard-crash of MATLAB, a machine reboot, or locking up of the acquisition
        % for some reason. If your laser doesn't have a watchdog timer, you should
        % define this method such that it takes an input argument and returns true.
        % BakingTray will still be able to turn off the laser if acquisition finishes
        % normally
        %
        % Inputs
        % timeInSeconds - The time-out beyond which the laser powers off. This should
        %                 be comfortably longer than the longest time it might take to
        %                 acquire a section. e.g. 40 minutes should be fine.



        laserStats = returnLaserStats(obj)
        % laserStats = returnLaserStats
        %
        % Behavior
        % It's probably not a bad idea to monitor the status of the laser over time.
        % This is worth doing because running these things 24/7, as we do, is rather
        % hard on them. So we can at least monitor the mood of our laser periodically
        % along with the acquisition of data. This method should simply return a
        % a string and it's output will just be logged to a file along with other
        % acquisition progress data. If you don't care about logging laser status
        % information, you just return an empty string. If you wish to log laser
        % information then it makes sense to return it in a consistent and machine
        % readable way. e.g. your string could be:
        % 'outputPower=1700mw,pumpPower=12000mw,wavelength=900nm,humidity=2\n'
        %
        % Avoid "%" signs in your string. They screw up subsequent sprintf lines.
        % You should ensure this method does something. It could be important for the
        % bake cycle.
        %
        % Returns
        % laserStats - a string


        laserID = readLaserID(obj)
        % readLaserID
        %
        % Behavior
        % Returns a string that contains the laser serial number, ID, etc.
        % If your laser has a serial command that returns this information then you
        % may use this. Failing that, you could hard-code the details into the
        % class or have it read the details from a text file you make. If you really
        % don't care about logging this, then your method should just return the laser
        % model as a string.
        %
        % You choose...

    end %close abstract methods


    %The following methods are common to all lasers
    methods

        function delete(obj)
            % laser.delete
            %
            % Purpose
            % Destructor for the laser superclass. Stops the polling and tuning timers
            % and detaches the serial callback. Subclasses call this (delete@laser)
            % before they close the serial port.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            obj.stopPollingSerialPort
            delete(obj.pollTimer)
            if isa(obj.tuningPollTimer,'timer')
                stop(obj.tuningPollTimer)
                delete(obj.tuningPollTimer)
            end
            % Detach the terminator callback before the port is closed by the subclass.
            if ~isempty(obj.hC) && isvalid(obj.hC)
                try
                    configureCallback(obj.hC,"off")
                catch
                end
            end
        end % delete

        function emission = emissionPossible(obj)
            % laser.emissionPossible
            %
            % Purpose
            % maitai returns this and it's needed for the readiness check but other lasers
            % lack it. So they just inherit this method that returns true.
            %
            % Outputs
            % emission - is always true

            emission = true;
        end % emissionPossible


        function [laserReady,msg] = isReady(obj)
            % laser.isReady
            %
            % Purpose
            % Returns true if the laser is currently in a state in which it is able to
            % excite the sample. So it should be, for example, turned on, modelocked,
            % with the shutter open, etc, etc. This command will be called at least
            % once per section. If it returns false the acquisition will stop and wait for
            % user intervention. Updates the hidden property isLaserReady.
            %
            % Outputs
            % laserReady - true/false depending on whether the laser is turned on and ready to go.
            % msg- if the laser is not ready, it should return a string that indicates the
            %      the reason for the failure. This will be logged or sent as a Slack.

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            laserReady = false;
            msg='';

            [shutterState,success] = obj.isShutterOpen;
            if ~success
                msg='No connection to laser';
                obj.isLaserReady=false;
                return
            end
            if ~obj.isLaserOn
                msg='Laser seems not to be powered on. Pump power is very low';
                obj.isLaserReady=false;
                return
            end
            if ~obj.emissionPossible
                msg='Laser is switched off and is not emitting';
                obj.isLaserReady=false;
                return
            end
            if shutterState==0
                msg='Laser shutter is closed';
                obj.isLaserReady=false;
                return
            end
            if ~obj.isModeLocked
                msg='Laser not modelocked';
                obj.isLaserReady=false;
                return
            end

            laserReady=true;
            obj.isLaserReady=laserReady;
        end % isReady


        function [inRange,msg] = isTargetWavelengthInRange(obj,targetWavelength)
            % laser.isTargetWavelengthInRange(targetWavelength)
            %
            % Purpose
            % Return false if the target wavelength supplied by the user is
            % out of the allowed range. True otherwise. targetWavelength is
            % defined in nm.
            %
            % Outputs
            % inRange - true/false

            if targetWavelength<obj.minWavelength || targetWavelength>obj.maxWavelength
                msg=sprintf('Wavelength %d nm is out of range -- max=%d nm, min=%d nm\n', ...
                    targetWavelength, obj.maxWavelength, obj.minWavelength);
                fprintf(msg);
                inRange=false;
                return
            end

            for ii=1:length(obj.bannedWavelengths)
                t_nm = obj.bannedWavelengths{ii};

                if targetWavelength>=t_nm(1) && targetWavelength<=t_nm(2)
                    msg=sprintf('The wavelength range %d to %d nm is currently not functional.\n', ...
                        t_nm);
                    fprintf(msg);
                    inRange=false;
                    return
                end

            end

            msg='';
            inRange=true;
        end % isTargetWavelengthInRange


        %%
        % Pockels control methods follow
        function connectToPockelsControlDAQ(obj)
            % laser.connectToPockelsControlDAQ
            %
            % Purpose
            % Connect to NI DAQ that will control Pockels power
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if ~isempty(obj.pockelsDAQ) && ischar(obj.pockelsDAQ) && ...
                ~isempty(obj.pockelsDigitalLine) && ischar(obj.pockelsDigitalLine)
                % Try to connect to the Pockels cell DAQ
                try
                    % Do not name the task because there is no need and we might have multiple
                    % laser classes making such a connection.
                    obj.hDO = dabs.ni.daqmx.Task;
                    obj.hDO(1).createDOChan(obj.pockelsDAQ, obj.pockelsDigitalLine); %Open one digital line
                catch ME
                    if obj.doPockelsPowerControl
                        fprintf('\n\n\nWARNING!!!\n\nFailed to connect to DAQ that gates Pockels cell power.\n')
                        fprintf('The Pockels cell will not turn on automatically with the laser.\n')
                        disp(ME.message)
                    end
                    obj.hDO = [];
                end
            end
            obj.switchPockelsCell % To turn it on if the laser is already on
        end % connectToPockelsControlDAQ

        function switchPockelsCell(obj)
            % laser.switchPockelsCell
            %
            % Purpose
            % Turn pockels cell on or off based on the reported power state of the laser
            % This method should be called from methods that turn on or turn off the
            % laser and also at the end of the constructor. It is not a callback.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if obj.doPockelsPowerControl && isempty(obj.hDO)
                fprintf('\nAuto-switch on of Pockels cell requested by DAQ not connected!\n')
            end

            if isempty(obj.hDO) || ~obj.doPockelsPowerControl
                return
            end

            obj.isPoweredOn;
            if obj.isLaserOn
                obj.hDO.writeDigitalData(1)
            else
            end
        end % switchPockelsCell

        function turnOffPockelsCell(obj)
            % laser.turnOffPockelsCell
            %
            % Purpose
            % Send DIO signal to turn pockels cell off.
            % This method should be called from methods that turn on or turn off the
            % laser and also at the end of the constructor. It is not a callback.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if obj.doPockelsPowerControl && isempty(obj.hDO)
                fprintf('\nSwitch on of Pockels cell requested by DAQ not connected!\n')
            end

            if isempty(obj.hDO) || ~obj.doPockelsPowerControl
                return
            end

            %Set line low to turn off Pockels cell
            obj.hDO.writeDigitalData(0);
        end % turnOffPockelsCell

        function turnOnPockelsCell(obj)
            % laser.turnOnPockelsCell
            %
            % Purpose
            % Send DIO signal to turn pockels cell on.
            % This method should be called from methods that turn on or turn off the
            % laser and also at the end of the constructor. It is not a callback.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if obj.doPockelsPowerControl && isempty(obj.hDO)
                fprintf('\nSwitch on of Pockels cell requested by DAQ not connected!\n')
            end

            if isempty(obj.hDO) || ~obj.doPockelsPowerControl
                return
            end

            %Set line high to turn on Pockels cell
            obj.hDO.writeDigitalData(1);

        end % turnOnPockelsCell


        %%
        % Connection verification
        function success = verifyCommsWithLaser(obj, probeCommand, nAttempts)
            % laser.verifyCommsWithLaser
            %
            % Purpose
            % Confirm that the laser is answering on an already-open serial port by
            % sending a harmless query, retrying it a few times before giving up.
            % Call this from connect rather than testing with a single query. An open
            % port does not guarantee that the first reply is not lost: the laser may
            % be slow to talk after the port opens, or a reply may be dropped. The
            % cost of getting this wrong is high, because a laser wrongly declared
            % unconnected at construction time stays dead for the whole session --
            % its constructor returns early, so the status poller is never started --
            % even though the port is open and the laser can still be driven by hand.
            %
            % Inputs
            % probeCommand - [string] a query which the laser answers and which
            %                changes nothing. e.g. obj.CMD_QUERY_SHUTTER
            % nAttempts - [optional scalar. 3 by default] how many times to try
            %
            % Outputs
            % success - true if the laser replied to the probe

            if nargin<3
                nAttempts = 3;
            end

            % Each probe attempt is bounded more tightly than a normal read so that a
            % laser which really is absent does not hold up startup for long. A laser
            % which is present replies in milliseconds.
            origTimeout = obj.serialReplyTimeoutSeconds;
            obj.serialReplyTimeoutSeconds = 2;

            success = false;
            for ii = 1:nAttempts
                success = obj.sendAndReceiveSerial(probeCommand);
                if success
                    break
                end
                fprintf('%s: no reply to "%s" from laser on %s (attempt %d of %d)\n', ...
                    class(obj), probeCommand, obj.controllerID, ii, nAttempts)
                pause(0.5)
            end

            obj.serialReplyTimeoutSeconds = origTimeout;
        end % verifyCommsWithLaser


        function serialTransportFailed(obj, reason)
            % laser.serialTransportFailed
            %
            % Purpose
            % Override of asyncSerial.serialTransportFailed. As well as dropping the
            % command queue (done by the superclass method) mark the laser as
            % disconnected, so that callers testing isLaserConnected stop believing in
            % a laser whose COM port has gone away. Without this the flag stays true
            % for the rest of the session, because it is otherwise written only by
            % connect and isControllerConnected. isLaserConnected is SetObservable, so
            % the GUI updates too.
            %
            % Only a successful laser.connect sets the flag true again.
            %
            % Inputs
            % reason - [string] why the transport is considered dead. Passed to the
            %          superclass method, which reports it.
            %
            % Outputs
            % none

            serialTransportFailed@BakingTray.asyncSerial(obj, reason)
            obj.isLaserConnected = false;
        end % serialTransportFailed


        %%
        % Serial port polling methods follow
        function startPollingSerialPort(obj)
            % laser.startPollingSerialPort
            %
            % Purpose
            % Create the serial-port poll timer if it does not exist and start it. The
            % timer periodically calls pollSerial to refresh the cached laser state.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            % If the timer does not exist we make it
            if isempty(obj.pollTimer)
                obj.pollPeriodInSeconds = obj.defaultPollPeriodInSeconds;
                obj.pollTimer = timer;
                obj.pollTimer.Name = [obj.controllerID, ' Regular laser serial port poller'];
                obj.pollTimer.Period  = obj.pollPeriodInSeconds;
                obj.pollTimer.TimerFcn = @(~,~) obj.pollSerial;
                obj.pollTimer.StopFcn =  @(~,~) [];
                obj.pollTimer.ExecutionMode = 'fixedDelay';
            end

            if isa(obj.pollTimer,'timer') && strcmp(obj.pollTimer.Running,'off')
                start(obj.pollTimer)
            end

        end % startPollingSerialPort

        function stopPollingSerialPort(obj)
            % laser.stopPollingSerialPort
            %
            % Purpose
            % Stop the serial-port poll timer if it exists and is running.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if isa(obj.pollTimer,'timer') && strcmp(obj.pollTimer.Running,'on')
                stop(obj.pollTimer)
            end
        end % stopPollingSerialPort

        function set.pollPeriodInSeconds(obj,newPeriod)
            % laser.set.pollPeriodInSeconds
            %
            % Purpose
            % Setter for the poll period of the regular laser serial port poller. Clamps
            % to a minimum of 1 s and, because a timer's Period can only be changed while
            % it is stopped, cycles the poll timer if it is currently running.
            %
            % Inputs
            % newPeriod - the requested poll period in seconds
            %
            % Outputs
            % none

            % Avoid polling too quickly.
            if newPeriod<1.0
                newPeriod = 1.0;
            end

            obj.pollPeriodInSeconds = newPeriod;   % store (does not recurse)

            % Period can only be changed on a stopped timer, so cycle it if needed
            if isa(obj.pollTimer,'timer') && isvalid(obj.pollTimer)
                wasRunning = strcmp(obj.pollTimer.Running,'on');
                if wasRunning
                    stop(obj.pollTimer)
                end

                obj.pollTimer.Period = newPeriod;
                if wasRunning && strcmp(obj.pollTimer.Running,'off')
                    start(obj.pollTimer)
                end
            end
        end % set.pollPeriodInSeconds

        function pausePolling(obj)
            % laser.pausePolling
            %
            % Purpose
            % Increment the pause counter so pollSerial skips its next tick(s). Commands
            % wrap themselves with pausePolling / resumePolling so a background poll can
            % not interleave with a multi-step command.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            obj.pollPauseDepth = obj.pollPauseDepth + 1;
        end % pausePolling

        function resumePolling(obj)
            % laser.resumePolling
            %
            % Purpose
            % Decrement the pause counter (see pausePolling). Polling resumes once the
            % counter returns to zero.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            obj.pollPauseDepth = max(obj.pollPauseDepth - 1, 0);
        end % resumePolling

        function pollSerial(obj)
            % laser.pollSerial
            %
            % Purpose
            % Refresh all cached laser state (shutter, power, wavelength, modelock) by
            % reading them from the hardware. Runs on the poll timer. Skips if a command
            % is holding the poller off or the previous read burst has not drained.
            % Subclasses may override this (e.g. maitai uses a fire-and-forget version).
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            % Skip if a command is holding the poller off, or the previous burst
            % hasn't drained yet (don't pile reads onto the queue).
            if obj.pollPauseDepth > 0 || obj.serialInFlight || ~isempty(obj.cmdQueue)
                return
            end

            try
                obj.isShutterOpen;
                obj.isPoweredOn;
                obj.readPower;
                obj.readWavelength;
                obj.isModeLocked;
            catch
                fprintf('laser.pollSerial failed to execute all laser status reads\n')
            end
        end % pollSerial



        %%
        % Methods associated with timer for higher rate polling during wavelength tuning
        function startTuningPoll(obj)
            % laser.startTuningPoll
            %
            % Purpose
            % Start (or keep running) a timer that polls the wavelength at twice the base
            % poll rate while the laser is tuning. It stops itself once the current
            % wavelength reaches the target (see tuningPollFcn). Call this from
            % setWavelength. Useful mainly for slow-tuning lasers (e.g. MaiTai).
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if isempty(obj.tuningPollTimer)
                obj.tuningPollTimer = timer;
                obj.tuningPollTimer.Name = [obj.controllerID, ' laser tuning wavelength poller'];
                obj.tuningPollTimer.TimerFcn = @(~,~) obj.tuningPollFcn;
                obj.tuningPollTimer.ExecutionMode = 'fixedDelay';
            end

            if strcmp(obj.tuningPollTimer.Running,'off')
                obj.tuningPollTimer.Period = max(obj.pollPeriodInSeconds/2, 0.1);
                start(obj.tuningPollTimer)
            end
        end % startTuningPoll


        function tuningPollFcn(obj)
            % laser.tuningPollFcn
            %
            % Purpose
            % Timer callback that polls the wavelength while the laser is tuning and
            % stops the tuning timer once the target is reached, so polling settles back
            % to the base rate. Reads via readWavelengthDuringTuning.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            if round(obj.currentWavelength) == round(obj.targetWavelength)
                stop(obj.tuningPollTimer)
                return
            end

            % Don't pile onto the queue if a command or a previous read is in progress.
            if obj.pollPauseDepth > 0 || obj.serialInFlight || ~isempty(obj.cmdQueue)
                return
            end

            obj.readWavelengthDuringTuning
        end % tuningPollFcn


        function readWavelengthDuringTuning(obj)
            % laser.readWavelengthDuringTuning
            %
            % Purpose
            % How the tuning poll reads the wavelength. Default is the standard (blocking)
            % read. Lasers with a fire-and-forget poll (e.g. MaiTai) override this to
            % queue the read instead of blocking while the laser tunes.
            %
            % Inputs
            % none
            %
            % Outputs
            % none

            obj.readWavelength;
        end % readWavelengthDuringTuning

    end %close methods

end %close classdef
