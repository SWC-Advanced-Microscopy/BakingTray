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
            BakingTray.utils.clearSerial(serialComms)
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
            obj.isPoweredOn
            obj.isModeLocked
            obj.switchPockelsCell            
        end %constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            fprintf('Disconnecting from tiberius laser\n')
            if ~isempty(obj.hC) && isa(obj.hC,'serial') && isvalid(obj.hC)
                fprintf('Closing serial communications with tiberius laser\n')
                flushinput(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                fclose(obj.hC);
                delete(obj.hC);
                delete(obj.hDO)
            end  
        end %destructor


        function success = connect(obj)
            obj.hC=serial(obj.controllerID,...
                'BaudRate', 19200, ...
                'FlowControl','software',...
                'Terminator','CR/LF', ...
                'TimeOut',5);
            try 
                fopen(obj.hC); %TODO: could test the output to determine if the port was opened
            catch ME
                fprintf(' * ERROR: Failed to connect to tiberius:\n%s\n\n', ME.message)
                success=false;
                return
            end

            flushinput(obj.hC) % Just in case
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
        end %connect


        function success = isControllerConnected(obj)
            if strcmp(obj.hC.Status,'closed')
                success=false;
            else
                [~,success] = obj.isShutterOpen;
            end
            obj.isLaserConnected=success;
        end


        function success = turnOn(obj)
            fprintf('Trying to turn on Tiberius\n')
            obj.sendAndReceiveSerial('LASER=1',false);
            obj.isLaserOn = true;
            success=true;
            obj.switchPockelsCell %Gate Pockels mains power
        end


        function success = turnOff(obj)
            obj.closeShutter; % Older tiberius lasers seem not to do this by default 
            obj.sendAndReceiveSerial('LASER=0',false);
            obj.isLaserOn = false;
            success=true;
            obj.switchPockelsCell %Gate Pockels mains power
        end

        function [powerOnState,details] = isPoweredOn(obj)
            % Just return true. It has no way to get this info
            powerOnState = obj.isLaserOn;
            details='';
        end


        function [laserReady,msg] = isReady(obj)
            laserReady = false;
            msg='';
            [shutterState,success] = obj.isShutterOpen;
            if ~success
                msg='No connection to laser';
                obj.isLaserReady=false;
                return
            end
            if ~obj.isPoweredOn
                msg='Laser seems not to be powered on. Pump power is very low';
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
        end


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
        end


        function success = openShutter(obj)
            success=obj.sendAndReceiveSerial('S=1',false);
            %%pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=true;
            end
        end


        function success = closeShutter(obj)
            success=obj.sendAndReceiveSerial('S=0',false);
            %%pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end


        function [shutterState,success] = isShutterOpen(obj)
            [success,reply]=obj.sendAndReceiveSerial('S?');
            if ~success
                shutterState=[];
                return
            end
            shutterState = str2double(reply(3)); %if open the command returns 1
            obj.isLaserShutterOpen=shutterState;
        end


        function wavelength = readWavelength(obj) 
            [success,wavelength]=obj.sendAndReceiveSerial('W?'); 
            if ~success
                wavelength=[];
                return
            end
            wavelength = str2double(wavelength(1:end));
            obj.currentWavelength=wavelength;
        end


        function success = setWavelength(obj,wavelengthInNM)
            success=false;
            if length(wavelengthInNM)>1
                fprintf('wavelength should be a scalar')
                return
            end
            if ~obj.isTargetWavelengthInRange(wavelengthInNM)
                return
            end
            cmd = sprintf('W=%d', round(wavelengthInNM));
            [success,wavelength]=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            obj.currentWavelength=wavelength;
            obj.targetWavelength=wavelengthInNM;

        end
   

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

        end


        function laserPower = readPower(~)
            % The Tiberius seems not to return laser power
            laserPower = nan;
        end


        function laserID = readLaserID(~)
            % there is no Tiberius command for returning detailed information
            laserID = 'tiberius';
        end


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
        end

        function success=setWatchDogTimer(~,~)
            % There seems to be no watchdog on the Tiberius
            success = true;
        end
        


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function [success,reply]=sendAndReceiveSerial(obj,commandString,waitForReply)
            % Send a serial command and optionally read back the reply
            if nargin<3
                waitForReply=true;
            end

            if isempty(commandString) || ~ischar(commandString)
                reply='';
                success=false;
                obj.logMessage(inputname(1),dbstack,6,'tiberius.sendReceiveSerial command string not valid.')
                return
            end

            fprintf(obj.hC,commandString);

            if ~waitForReply
                reply=[];
                success=true;
                if obj.hC.BytesAvailable>0
                    fprintf('Not waiting for reply by there are %d BytesAvailable\n',obj.hC.BytesAvailable)
                end
                return
            end

            reply=fgets(obj.hC);
            doFlush=1; %TODO: not clear right now if flushing the buffer is even the correct thing to do. 
            if obj.hC.BytesAvailable>0
                if doFlush
                    fprintf('Read in from the tiberius buffer using command "%s" but there are still %d BytesAvailable. Flushing.\n', ...
                        commandString, obj.hC.BytesAvailable)
                    flushinput(obj.hC)
                else
                    fprintf('Read in from the tiberius buffer using command "%s" but there are still %d BytesAvailable. NOT FLUSHING.\n', ...
                        commandString, obj.hC.BytesAvailable)
                end
            end

            if ~isempty(reply)
                reply(end-1:end)=[];
            else
                msg=sprintf('Laser serial command %s did not return a reply\n',commandString);
                success=false;
                obj.logMessage(inputname(1),dbstack,6,msg)
                return
            end

            success=true;
        end

    end %close methods

end %close classdef 
