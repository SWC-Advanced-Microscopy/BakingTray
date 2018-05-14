classdef FaulhaberMCDC < cutter & loghandler
    % Faulhaber motor controller. Before use, set up your controller with the 
    % motor you have and the encoder. Run IXRMOD if you have no encoder. Save
    % the settings to the controller's EEPROM with EEPSAV. That way you do not
    % need to supply additional settings every time you connect to the motor
    %
    % For more information on the cutter, see the abstract class.
    %
    % Rob Campbell - Basel, 2016


    properties 

        %controllerID should be a cell array of strings that can be fed to the serial port command. 
        %e.g. controllerID = {'COM1','BaudRate',4800};

        motorMaxSpeed = 60; %max motor speed in cycles per second %TODO: confirm
        maxControlValue=30000; %TODO: find the max control value. e.g. when motor 
                                %commanded to this setting it should produdce motorMaxSpeed cycles/sec
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


            fprintf(['Setting up Faulhaber MCDC3006 DC motor controller.\n',...
                'Motor max speed: %d revs per second.\n'], obj.motorMaxSpeed);
            BakingTray.utils.clearSerial(serialComms)
            obj.controllerID=serialComms;
            success = obj.connect;

            obj.stopVibrate; % Because rarely on some systems the vibramtome starts on connect

            if ~success
                fprintf(['\n\nWARNING!\nComponent FaulhaberMCDC failed to connect to vibrotome controller.\n',...
                    'Closing serial port\n'])
                fclose(obj.hC)
                delete(obj.hC)
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
            success = success &  ~isempty(strfind(reply,'Version'));
            obj.isCutterConnected=success;
        end %isControllerConnected


        function success = enable(obj)
            success=obj.sendReceiveSerial('EN');
        end %enable


        function success = disable(obj)
            success=obj.sendReceiveSerial('DI');
        end %disable


        function success = startVibrate(obj,cyclesPerSec)
            obj.enable;
            speedRatio=cyclesPerSec/obj.motorMaxSpeed;
            if speedRatio>1
                obj.logMessage(inputname(1),dbstack,4,'Capping motor speed to max.')
                speedRatio=1;
            end
            commandedSpeed = round(obj.maxControlValue*speedRatio);
            success = obj.sendReceiveSerial(sprintf('V%d',commandedSpeed));
        end %startVibrate


        function success = stopVibrate(obj)
            success = obj.sendReceiveSerial('V1000');
            pause(0.4)
            success = obj.sendReceiveSerial('V0');
            obj.disable;
        end %stopVibrate


        function cyclesPerSec = readVibrationSpeed(obj)
            cyclesPerSec=false;
        end %readVibrationSpeed



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

            if strfind(reply,'Unknown command')
                success=false;
            else 
                success=true;
            end
        end %sendReceiveSerial


    end %close methods


end % close class def
