classdef SWCserialCutter< cutter & loghandler
    % Serial comms class for the SWC DC motor controller.
    %
    % The SWC basic serial controller is open loop.
    %
    %
    % For more information, see also the abstract class (cutter).
    %
    % Rob Campbell - SWC, 2025


    properties

        %controllerID should be a cell array of strings that can be fed to the serial port command.
        %e.g. controllerID = {'COM1','BaudRate',4800};

        maxMotorRPM= 4000; % max RPM for safety
    end %close public properties


    methods
k
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = SWCserialCutter(serialComms,logObject)
        % function obj = SWCserialCutter(serialComms,logObject)
            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end


            BakingTray.utils.clearSerial(serialComms)
            obj.controllerID=serialComms;
            success = obj.connect;


            if ~success
                fprintf(['\n\nWARNING!\nComponent SWCserialCutter failed to connect to vibrotome controller.\n',...
                    'Closing serial port\n'])
                fclose(obj.hC)
                delete(obj.hC)
                return
            end

            obj.stopVibrate; % Just in case the vibramtome starts up on connect

        end %constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            if ~isempty(obj.hC) && isa(obj.hC,'serial')
                fprintf('Closing connection to SWC Serial comms DC motor controller\n')
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

            [success,reply] = obj.sendReceiveSerial('V0');
            success = success &  contains(reply,'V0');
            obj.isCutterConnected=success;
        end %isControllerConnected


        function success = enable(obj)
            success=true
        end %enable


        function success = disable(obj)
            success=true;
        end %disable


        function success = startVibrate(obj,targetSpeed)
            obj.enable;
            if ~isscalar(targetSpeed) || targetSpeed>obj.maxMotorRPM
                return
            end
            success = obj.sendReceiveSerial(sprintf('V%d',commandedSpeed));
        end %startVibrate


        function success = stopVibrate(obj)
            success = obj.sendReceiveSerial('V0');
            obj.disable;
        end %stopVibrate


        function cyclesPerSec = readVibrationSpeed(obj)
            cyclesPerSec = false;
        end %readVibrationSpeed



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function [success,reply] = sendReceiveSerial(obj,commandString)
            %Send a serial command to the connected port and get back the reply
            if isempty(commandString) || ~ischar(commandString)
                reply='';
                success=false;
                obj.logMessage(inputname(1),dbstack,6,'SWCserialCutter.sendReceiveSerial command string not valid.')
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
