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
% For docs, please see the laser abstract class.
%
%
% Rob Campbell - Basel 2016


    properties (Hidden)
        % Implement a "grace period" between the pump power ramping up and down
        % and the user having issued a turn/on off
        powerCommandTime = NaT
        powerStateGraceSeconds = 20
    end

    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = maitai(serialComms,logObject)
        % function obj = maitai(serialComms,logObject)
        % serialComms is a string indicating the serial port we should connect to

            if nargin<1
                error('maitai requires at least one input argument: you must supply the laser COM port as a string')
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
                %TODO: is it possible to delete it here?
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

            obj.startPollingSerialPort
        end %constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            fprintf('Disconnecting from MaiTai laser\n')
            delete@laser(obj);
            if ~isempty(obj.hC) && isvalid(obj.hC)
                fprintf('Closing serial communications with MaiTai laser\n')
                flush(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                delete(obj.hC);
                delete(obj.hDO)
            end
        end %destructor


        function success = connect(obj)
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
        end %connect


        function success = isControllerConnected(obj)
            if isempty(obj.hC) || ~isvalid(obj.hC)
                success=false;
            else
                [~,success] = obj.isShutterOpen;
            end
            obj.isLaserConnected=success;
        end


        function success = turnOn(obj)

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

        end


        function success = turnOff(obj)

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

        end %turnOff

        function [powerOnState,details] = isPoweredOn(obj)
            % Is the laser powered on?
            %
            % Outputs
            % powerOnState - true if powered on, false otherwise
            % details - string that reflects pump power
            %
            % Behavior
            % When run this method sets the isLaserOn property

            % Bail out if we are within the grace period
            if ~isnat(obj.powerCommandTime) && ...
                    seconds(datetime('now') - obj.powerCommandTime) < obj.powerStateGraceSeconds
                powerOnState = obj.isLaserOn;   % trust the recent command; don't clobber
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

        end


        function modelockState = isModeLocked(obj)

            [success,reply]=obj.sendAndReceiveSerial('*STB?'); %modelock state embedded in the second bit of this 8 bit number
            if ~success %If we can't talk to it, we assume it's also not modelocked (maybe questionable, but let's go with this for now)
                modelockState=0;
                obj.isLaserModeLocked=modelockState;
                return
            end

            %extract modelock state
            bits = fliplr(dec2bin(str2double(reply),8));
            if strcmp(bits(2),'1')
                modelockState=true;
            else
                modelockState=false;
            end
            obj.isLaserModeLocked=modelockState;
        end


        function success = openShutter(obj)

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
        end


        function success = closeShutter(obj)

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('SHUTTER 0',false);
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end


        function [shutterState,success] = isShutterOpen(obj)

            [success,reply]=obj.sendAndReceiveSerial('SHUTTER?');

            % If it fails to read, return whatever was the last state
            if ~success
                disp('Failed to read shutter state. Returning last known state')
                shutterState=obj.isLaserShutterOpen;
                return
            end
            shutterState = str2double(reply); %if open the command returns 1
            obj.isLaserShutterOpen=shutterState;
        end


        function wavelength = readWavelength(obj)
            [success,wavelength]=obj.sendAndReceiveSerial('READ:WAVELENGTH??');
            if ~success
                wavelength=[];
                return
            end
            wavelength = str2double(wavelength(1:end-2));
            obj.currentWavelength=wavelength;
        end


        function success = setWavelength(obj,wavelengthInNM)

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

        end % setWavelength


        function tuning = isTuning(obj)
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

        end


        function laserPower = readPower(obj)
            [success,laserPower]=obj.sendAndReceiveSerial('READ:POWER?');
            if ~success
                laserPower=[];
                return
            end
            laserPower = str2double(laserPower(1:end-1))*1E3;
            laserPower = round(laserPower);
            obj.currentPower_mW = laserPower;
        end


        function laserID = readLaserID(obj)
            [success,laserID]=obj.sendAndReceiveSerial('*IDN?');
            if ~success
                laserID=[];
                return
            end
        end


        function laserStats = returnLaserStats(obj)
            lambda = obj.readWavelength;
            outputPower = obj.readPower;
            pumpPower = obj.readPumpPower;
            pumpCurrent = obj.readPumpLaserCurrent;
            humidity = obj.readHumidity;

            laserStats=sprintf('wavelength=%dnm,outputPower=%dmW,pumpPower=%dmW,pumpCurrent=%0.1f,humidity=%0.1f', ...
                lambda,outputPower,pumpPower,pumpCurrent,humidity);
        end

        function success=setWatchDogTimer(obj,value)

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
        end


        % MaiTai specific
        function laserPower = readPumpPower(obj)
            % Return pump power as a scalar
            [success,laserPower]=obj.sendAndReceiveSerial('READ:PLASER:POWER?');
            if ~success
                laserPower=[];
                return
            end
            laserPower = str2double(laserPower(1:end-1))*1E3;
            laserPower = round(laserPower);
            obj.currentPumpPower_mW = laserPower;
        end

        function pLasI = readPumpLaserCurrent(obj)
            [success,pLasI]=obj.sendAndReceiveSerial('READ:PLASER:PCURRENT?');
            if ~success
                pLasI=[];
                return
            end
            pLasI = str2double(pLasI(1:end-1));
        end

        function laserHumidity = readHumidity(obj)
            [success,laserHumidity]=obj.sendAndReceiveSerial('READ:HUM?');
            if ~success
                laserHumidity=[];
                return
            end
            laserHumidity = str2double(laserHumidity(1:end-3));
        end

        function warmedUpValue = readWarmedUp(obj)
            %Return a scalar that defines whether the laser is warmed up
            %100 means warmed up. Returns empty if nothing was read back.
            [success,warmedUpValue]=obj.sendAndReceiveSerial('READ:PCTWarmedup?');
            if ~success
                warmedUpValue=[];
                return
            end
            warmedUpValue = str2double(warmedUpValue(1:end-1));
        end

        function emission = emissionPossible(obj)
            [success,reply]=obj.sendAndReceiveSerial('*STB?'); %emission state embedded in the first bit of this 8 bit number
            if ~success %If we can't talk to it, we assume it's also not emitting (maybe questionable, but let's go with this for now)
                emission=false;
                return
            end

            %extract modelock state
            bits = fliplr(dec2bin(str2double(reply),8));
            if strcmp(bits(1),'1')
                emission=1;
            else
                emission=0;
            end
        end

        function readErrorCodeHistory(obj)
            % Print to screen Mai Tai error codes
            [success,reply]=obj.sendAndReceiveSerial('PLAS:AHIS?');
            disp(reply)

        end

        function readLastErrorCode(obj)
            % Print to screen Mai Tai error codes
            [~,reply]=obj.sendAndReceiveSerial('PLAS:ERRC?');
            disp(reply)

        end


    end %close methods

end %close classdef
