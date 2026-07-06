classdef tiberius < laser & loghandler
%%  tiberius - control class for tiberius lasers
%
%
% Example
% M = tiberius('COM1');
%
% Laser control component for Tiberius lasers from ThorLabs.
%
% For docs, please see the laser abstract class.
%
%
% Rob Campbell - SWC 2021


    properties (Constant,Hidden)

    end


    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = tiberius(serialComms,logObject)
        % function obj = tiberius(serialComms,logObject)
        % serialComms is a string indicating the serial port we should connect to

            if nargin<1
                error('tiberius requires at least one input argument: you must supply the laser COM port as a string')
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
                [~,s] = obj.isShutterOpen;
                if s==true
                    success=true;
                else
                    fprintf('Failed to communicate with tiberius laser\n');
                    success=false;
                end
            end
            obj.isLaserConnected=success;
        end % connect


        function success = isControllerConnected(obj)
            if isempty(obj.hC) || ~isvalid(obj.hC)
                success=false;
            else
                [~,success] = obj.isShutterOpen;
            end
            obj.isLaserConnected=success;
        end % isControllerConnected


        function success = turnOn(obj)
            fprintf('Trying to turn on Tiberius\n')

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            obj.sendAndReceiveSerial('LASER=1',false);
            obj.isLaserOn = true;
            success=true;
            obj.switchPockelsCell %Gate Pockels mains power
        end % turnOn


        function success = turnOff(obj)
            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            obj.closeShutter; % Older tiberius lasers seem not to do this by default
            obj.sendAndReceiveSerial('LASER=0',false);
            obj.isLaserOn = false;
            success=true;
            obj.switchPockelsCell %Gate Pockels mains power
        end % turnOff

        function [powerOnState,details] = isPoweredOn(obj)
            % Just return true. It has no way to get this info
            powerOnState = obj.isLaserOn;
            details='';
        end % isPoweredOn


        function modelockState = isModeLocked(obj)
            [success,reply]=obj.sendAndReceiveSerial('STATUS?');
            if ~success %If we can't talk to it, we assume it's also not modelocked (maybe questionable, but let's go with this for now)
                modelockState=0;
                obj.isLaserModeLocked=modelockState;
                return
            end

            %extract modelock state: R means modelocked and N means not.
            if strcmp(reply,'R')
                modelockState = true;
            elseif strcmp(reply,'N')
                modelockState = false;
            else
                fprintf('Unknown reply for modelock state: "%s"\n', reply)
                modelockState = false;
            end

            obj.isLaserModeLocked=modelockState;
        end % isModeLocked


        function success = openShutter(obj)

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('S=1',false);
            %%pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=true;
            end
        end % openShutter


        function success = closeShutter(obj)

            obj.pausePolling
            c = onCleanup(@() obj.resumePolling);

            success=obj.sendAndReceiveSerial('S=0',false);
            %%pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end % closeShutter


        function [shutterState,success] = isShutterOpen(obj)
            [success,reply]=obj.sendAndReceiveSerial('S?');
            if ~success
                shutterState=[];
                return
            end
            shutterState = str2double(reply(3)); %if open the command returns 1
            obj.isLaserShutterOpen=shutterState;
        end % isShutterOpen


        function wavelength = readWavelength(obj)
            [success,wavelength]=obj.sendAndReceiveSerial('W?');
            if ~success
                wavelength=[];
                return
            end
            wavelength = str2double(wavelength(1:end));
            obj.currentWavelength=wavelength;
        end % readWavelength


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
            cmd = sprintf('W=%d', round(wavelengthInNM));
            success=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            obj.targetWavelength=wavelengthInNM;

        end % setWavelength


        function tuning = isTuning(obj)
            %First get the desired (setpoint) wavelength
            [success,wavelengthDesired]=obj.sendAndReceiveSerial('W?');
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
            % The Tiberius seems not to return laser power
            laserPower = nan;
            obj.currentPower_mW = laserPower;
        end % readPower


        function laserID = readLaserID(~)
            % there is no Tiberius command for returning detailed information
            laserID = 'tiberius';
        end % readLaserID


        function laserStats = returnLaserStats(obj)
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
            % There seems to be no watchdog on the Tiberius
            success = true;
        end % setWatchDogTimer



    end %close methods

end %close classdef
