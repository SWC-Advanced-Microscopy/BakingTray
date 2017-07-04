classdef dummyCutter < cutter & loghandler
    % dummy cutter class. 

    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = dummyCutter(~,logObject)
            if nargin>1 %TODO: I doubt we need this
                obj.attachLogObject(logObject);
            end

        end %constructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function success = connect(obj)
            success=true;
            obj.isCutterConnected=success;
        end

        function success = isControllerConnected(obj)
            success=true;
            obj.isCutterConnected=success;
        end

        function success = enable(obj)
            success=true;
        end

        function success = disable(obj)
            success=true;
        end

        function success = startVibrate(obj,cyclesPerSec)
           success=true;
           obj.isCutterVibrating=true;
        end

        function success = stopVibrate(obj)
            success = true;
            obj.isCutterVibrating=false;
        end

        function cyclesPerSec = readVibrationSpeed(obj)
            cyclesPerSec=1;
        end

    end %close methods


end % close class def