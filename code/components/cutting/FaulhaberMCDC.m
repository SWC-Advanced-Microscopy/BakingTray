classdef FaulhaberMCDC < cutter & loghandler
    % Faulhaber motor controller. Before use, set up your controller with the
    % motor you have and the encoder.
    %
    % This class was written for a Faulhaber MCDC 3006 S. It will NOT work with the
    % newer MC 5005.
    %
    % This class can drive the vibratome too hard if not properly configured. Therefore,
    % **BEFORE RUNNING IT**, first see the instructions for setting up the vibratome:
    % https://bakingtray.mouse.vision/getting-started/hardware-setup/setting_up_vt1000
    %
    %
    % For more information, see also the abstract class (cutter).
    %
    % Rob Campbell - Basel, 2016; SWC, 2023


    properties

        %controllerID should be a cell array of strings that can be fed to the serial port command.
        %e.g. controllerID = {'COM1','BaudRate',4800};

        motorMaxSpeed = 60; %max motor speed in cycles per second. NOTE: we later normalise by this
                            %number so it's a bad idea to change it.
        maxControlValue=30000; %TODO: find the max control value. e.g. when motor
                                %commanded to this setting it should produdce motorMaxSpeed cycles/sec

        modeMap % dictionary to return mode state
    end %close public properties


    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = FaulhaberMCDC(serialComms,logObject)
        % function obj = FaulhaberMCDC(serialComms,logObject)
            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end

            % Populate the mode dictionary
            obj.modeMap = containers.Map({'I','D','S','A','H','E','G','V'}, ...
                {'IXRMOD','CONTMOD','STEPMOD','APCMOD','ENCMOD','ENCSPEED','GEARMOD','VOLTMOD'});

            BakingTray.utils.clearSerial(serialComms)
            obj.controllerID=serialComms;
            success = obj.connect;


            if ~success
                fprintf(['\n\nWARNING!\nComponent FaulhaberMCDC failed to connect to vibrotome controller.\n',...
                    'Closing serial port\n'])
                fclose(obj.hC);
                delete(obj.hC);
                return
            end

            obj.stopVibrate; % Because rarely on some systems the vibramtome starts on connect
            if strcmp(obj.readMode,'IXRMOD')
                fprintf(['Setting up Faulhaber MCDC3006 DC motor controller.\n',...
                    'Motor max speed: %d revs per second.\n'], obj.motorMaxSpeed);
            else
                % TODO -- report true max speed in RPM if in CONTMOD
            end
        end %constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            if ~isempty(obj.hC) && isa(obj.hC,'serial')
                fprintf('Closing connection to Faulhaber MCDC motor controller\n')
                obj.stopVibrate;
                fclose(obj.hC);
                delete(obj.hC);
            end
        end %destructor




        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj)

            if isempty(obj.controllerID)
                fprintf('Can not connect to Faulhaber MCDC. No controller ID defined.\n')
                success=false;
                return
            end

            if ischar(obj.controllerID)
                obj.hC = serial(obj.controllerID);
            elseif iscell(obj.controllerID)
                obj.hC = serial(obj.controllerID{:});
            else
                success=false;
            end

            fopen(obj.hC);


            success = obj.isControllerConnected;

        end %connect


        function success = isControllerConnected(obj)
            if isempty(obj.hC)
                success=false;
                return
            end
            [success,reply] = obj.sendReceiveSerial('VER');
            success = success &  contains(reply,'Version');
            obj.isCutterConnected=success;
        end %isControllerConnected


        function success = enable(obj)
            success=obj.sendReceiveSerial('EN');
        end %enable


        function success = disable(obj)
            success=obj.sendReceiveSerial('DI');
        end %disable


        function success = startVibrate(obj,targetSpeed)
            obj.enable;
            if strcmp(obj.readMode,'IXRMOD')
                %Legacy behavior
                speedRatio=targetSpeed/obj.motorMaxSpeed;
                if speedRatio>1
                    obj.logMessage(inputname(1),dbstack,4,'Capping motor speed to max.')
                    speedRatio=1;
                end
                commandedSpeed = round(obj.maxControlValue*speedRatio);
            elseif strcmp(obj.readMode,'CONTMOD')
                % This will be RPM
                commandedSpeed = targetSpeed;
            else
                success = false;
                fprintf('Device is in mode %s. Expected IXRMOD or CONTMOD\n', ...
                    obj.readMode);
            end
            success = obj.sendReceiveSerial(sprintf('V%d',commandedSpeed));
        end %startVibrate


        function success = stopVibrate(obj)
            success = obj.sendReceiveSerial('V1000');
            pause(0.4)
            success = obj.sendReceiveSerial('V0');
            obj.disable;
        end %stopVibrate


        function cyclesPerSec = readVibrationSpeed(obj)
            cyclesPerSec = false;
        end %readVibrationSpeed


        function cyclesPerSec = readTargetVelocity(obj)
            [~,reply] = obj.sendReceiveSerial('GV');
            cyclesPerSec = str2double(reply);
        end %readVibrationSpeed


        function set2IXRMOD(obj)
            % Set device to IXRMOD mode, which does not use the encoder
            obj.genericModeSet('IXRMOD');
        end %set2IXRMOD


        function set2CONTMOD(obj)
            % Set device to CONTMOD mode, which uses the encoder
            obj.genericModeSet('CONTMOD');
        end %set2CONTMOD


        function genericModeSet(obj,mode)
            obj.sendReceiveSerial(mode);
            if strcmp(obj.readMode,mode)
                fprintf('Set to %s\n',mode)
                obj.sendReceiveSerial('EEPSAV');
            else
                fprintf('Failed to set to %s. In mode %s\n',mode,obj.readMode)
            end
        end %genericModeSet


        function deviceMode=readMode(obj)
            % Return device
            [~,tMode] = obj.sendReceiveSerial('GMOD');
            deviceMode =  obj.modeMap(tMode);
        end %readMode

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function [success,reply] = sendReceiveSerial(obj,commandString)
            %Send a serial command to the connected port and get back the reply
            if isempty(commandString) || ~ischar(commandString)
                reply='';
                success=false;
                obj.logMessage(inputname(1),dbstack,6,'FaulhaberMCDC.sendReceiveSerial command string not valid.')
                return
            end
            fprintf(obj.hC,commandString);
            reply=fgetl(obj.hC);
            reply(end)=[];
            if strfind(reply,'Unknown command')
                success=false;
            else
                success=true;
            end
        end %sendReceiveSerial


    end %close methods


end % close class def
