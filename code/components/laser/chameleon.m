classdef chameleon < laser & loghandler
%%  chameleon - control class for Coherent Chameleon lasers
%
%
% Example
% M = chameleon('COM1');
%
% Laser control component for Chameleon lasers from Coherent. 
%
% For docs, please see the laser abstract class. 
%
%
% Rob Campbell - Basel 2017

    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = chameleon(serialComms,logObject)
        % function obj = chameleon(serialComms,logObject)

            if nargin<1
                error('chameleon requires at least one input argument: you must supply the laser COM port as a string')
            end
            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end

            obj.maxWavelength=1100;
            obj.minWavelength=700;

            fprintf('\nSetting up Chameleon laser communication on serial port %s\n', serialComms);
            BakingTray.utils.clearSerial(serialComms)
            obj.controllerID=serialComms;
            success = obj.connect;

            if ~success
                fprintf('Component chameleon failed to connect to laser over the serial port.\n')
                %TODO: is it possible to delete it here?
            end

            %Set the target wavelength to equal the current wavelength
            obj.targetWavelength=obj.currentWavelength;

            %Report connection and humidity
            fprintf('Connected to Chameleon laser on %s, laser humidity is %0.2f%%\n\n', ...
             serialComms, obj.readHumidity)

            obj.friendlyName = 'Chameleon';
        end %constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            fprintf('Disconnecting from Chameleon laser\n')
            if ~isempty(obj.hC) && isa(obj.hC,'serial') && isvalid(obj.hC)
                fprintf('Closing serial communications with Chameleon laser\n')
                flushinput(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
                fclose(obj.hC);
                delete(obj.hC);
            end  
        end %destructor


        function success = connect(obj)
            obj.hC=serial(obj.controllerID,'BaudRate',19200, ...
                        'TimeOut',5, ...
                        'Terminator', 'CR/LF');
            
            try 
                fopen(obj.hC); %TODO: could test the output to determine if the port was opened
            catch ME
                fprintf(' * ERROR: Failed to connect to Chameleon:\n%s\n\n', ME.message)
                success=false;
                return
            end

            flushinput(obj.hC) % Just in case
            success = false;
            if ~isempty(obj.hC)
                s1 = obj.sendAndReceiveSerial('ECHO=0'); % So we don't get back a copy of the command
                s2 = obj.sendAndReceiveSerial('PROMPT=0'); % So we don't get the "CHAMELEON> " text
                s3 = obj.setWatchDogTimer(0); % Ensure laser does not turn off 

                if s1==1 && s2==1 && s3==1
                    success=true;
                else
                    fprintf('ERROR: Failed to communicate with chameleon: ECHO=0 returned nothing\n')
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
            % TODO
            % The Chameleon can't be turned on remotely. You have to use
            % the key. So think what to do about this. 
            if ~obj.readWarmedUp
                fprintf('Laser is not warmed up.\n')
                return
            end
            % TODO: the following not finished because this won't work if
            % the key switch is off 
            success=obj.sendAndReceiveSerial('L=1');
            obj.isLaserOn=success;
        end


        function success = turnOff(obj)
            success=obj.sendAndReceiveSerial('L=0');
            if success
                obj.isLaserOn=false;
            end
        end

        function powerOnState = isPoweredOn(obj)
           	[success,reply]=obj.sendAndReceiveSerial('?L');
            if ~success
                powerOnState=0;
                return
            end
            
            powerOnState = (str2double(reply)==1);
            
            obj.isLaserOn=powerOnState;
        end


        function [laserReady,msg] = isReady(obj)
           % TODO: not done
            laserReady = false;
            msg='';
            [shutterState,success] = obj.isShutterOpen;
            if ~success
                msg='No connection to laser';
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
            [success,reply]=obj.sendAndReceiveSerial('?MDLK'); %modelock state embedded in the second bit of this 8 bit number
            if ~success %If we can't talk to it, we assume it's also not modelocked (maybe questionable, but let's go with this for now)
                modelockState=false;
                obj.isLaserModeLocked=modelock;
                return
            end

            %extract modelock state
            modelockState = str2double(reply);
            modelockState = (modelockState==1); %Because it can equal 2 (CW) or 0 (Off)
            obj.isLaserModeLocked=modelockState;
        end


        function success = openShutter(obj)
            success=obj.sendAndReceiveSerial('SHUTTER=1');
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=true;
            end
        end


        function success = closeShutter(obj)
            success=obj.sendAndReceiveSerial('SHUTTER=0');
            pause(0.75) %Because it takes the laser about a second to register the change
            if success
                obj.isLaserShutterOpen=false;
            end
        end


        function [shutterState,success] = isShutterOpen(obj)
            [success,reply]=obj.sendAndReceiveSerial('?S');
            if ~success
                shutterState=[];
                return
            end
            shutterState = str2double(reply); %if open the command returns 1
            obj.isLaserShutterOpen=shutterState;
        end


        function wavelength = readWavelength(obj) 
            [success,wavelength]=obj.sendAndReceiveSerial('?VW'); 
            if ~success
                wavelength=[];
                return
            end
            wavelength = str2double(wavelength);
            if ~isnan(wavelength)
                obj.currentWavelength=wavelength;
            else
                fprintf('Failed to read wavelength from Chameleon. Likely laser is tuning.\n')
            end
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
            cmd = sprintf('WAVELENGTH=%d', round(wavelengthInNM));
            [success,wavelength]=obj.sendAndReceiveSerial(cmd,false);
            if ~success
                return
            end
            obj.currentWavelength=wavelength;
            obj.targetWavelength=wavelengthInNM;

        end
   

        function tuning = isTuning(obj)
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
            
        end


        function laserPower = readPower(obj)
            [success,laserPower]=obj.sendAndReceiveSerial('?UF');
            if ~success
                laserPower=[];
                return
            end
            laserPower = str2double(laserPower);
        end


        function laserID = readLaserID(obj)
            [success,laserID]=obj.sendAndReceiveSerial('?SN');
            if ~success
                laserID=[];
                return
            end
            laserID = ['Chameleon, Serial Number: ', laserID];
        end


        function laserStats = returnLaserStats(obj)
            lambda = obj.readWavelength;
            outputPower = obj.readPower;
            humidity = obj.readHumidity;

            laserStats=sprintf('wavelength=%dnm,outputPower=%dmW,humidity=%0.1f', ...
                lambda,outputPower,humidity);
        end



        % Chameleon specific
        function laserHumidity = readHumidity(obj)
            % I think some lasers don't have sensor and just return 0
            [success,laserHumidity]=obj.sendAndReceiveSerial('?RH');
            if ~success
                laserHumidity=[];
                return
            end
            laserHumidity = str2double(laserHumidity);
        end

        function warmedUpValue = readWarmedUp(obj)
            %Return a bool that defines whether the laser is warmed up and
            %ready emit.
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
        end

        function success=setWatchDogTimer(obj,value)
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
                obj.logMessage(inputname(1),dbstack,6,'chameleon.sendReceiveSerial command string not valid.')
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
                    fprintf('Read in from the Chameleon buffer using command "%s" but there are still %d BytesAvailable. Flushing.\n', ...
                        commandString, obj.hC.BytesAvailable)
                    flushinput(obj.hC)
                else
                    fprintf('Read in from the Chameleon buffer using command "%s" but there are still %d BytesAvailable. NOT FLUSHING.\n', ...
                        commandString, obj.hC.BytesAvailable)
                end
            end

            if ~isempty(reply)
                reply(end)=[];
            else
                msg=sprintf('Laser serial command %s did not return a reply\n',commandString);
                success=false;
                obj.logMessage(inputname(1),dbstack,6,msg)
                return
            end


            %TODO: improve check of success?
            success=true;
        end

    end %close methods

end %close classdef 