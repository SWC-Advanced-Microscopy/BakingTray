classdef JaneliaLeicaController < cutter & loghandler
    % Interface for Janelia controller for Leica vibratome. 
    %
    % For more information on the cutter, see the abstract class.
    %
    % Rob Campbell - Basel, 2017

    
    properties 

    end %close public properties
      
    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Constructor
        function obj = JaneliaLeicaController(deviceName,logObject)

            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end


            fprintf('Setting up Janelia Leica Controller.\n')
            obj.controllerID=deviceName;
            success = obj.connect;
            
            if ~success
                fprintf('Component JaneliaLeicaController failed to connect to vibrotome controller.\n')
                %TODO: is it possible to delete it here?
            end
        end % Constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Destructor
        function delete(obj)
            if ~isempty(obj.hC)
                obj.stopVibrate;
                delete(obj.hC);
            end
        end % Destructor




        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj)

            success=false;
            if isempty(obj.controllerID)
                fprintf('Can not connect to JaneliaLeicaController. No controller ID defined.\n')

                return
            end

            try
                obj.hC = dabs.no.daqmx.Task.empty;
                obj.hC = dabs.ni.daqmx.Task('cutter');
                obj.hC.createDOChan(obj.controllerID,'port0/line0');
                success=true;
                obj.isCutterConnected=success;
            catch 
                fprintf('Failed to connect to DAQ for JaneliaLeicaController.\n')
            end

        end %connect


        function success = isControllerConnected(obj)
            success = obj.isControllerConnected;
        end %isControllerConnected


        function success = enable(obj)
            success=true;
        end %enable


        function success = disable(obj)
            success=false;
        end %disable


        function success = startVibrate(obj,~)
            try
                obj.hC.writeDigitalData(1);
                success = true;
            catch
                success = false;
            end
        end %startVibrate


        function success = stopVibrate(obj,~)
            try
                obj.hC.writeDigitalData(0);
                success = true;
            catch
                success = false;
            end
        end %stopVibrate

        function cyclesPerSec = readVibrationSpeed(obj)
            cyclesPerSec=false;
        end %readVibrationSpeed

    end %close methods


end % close class def