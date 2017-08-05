classdef dummyLaser < laser %& loghandler
%%  dummyLaser
%
% Dummy laser control class for debugging or running in, say, a simulated ScanImage session. 
%
% Rob Campbell - Basel 2016


    properties
        verbose=false
    end

    properties (Hidden)
        %These properties are associated with a timer that simulates the tuning process of the 
        %laser to a new wavelength. The purpose of this is for the laser GUI to update 
        %realistically when the dummy laser is connected. 
        nanoMetersPerSecond = 10    % Rate at which the wavelength changes
        wavelengthTimer             % To simulate slow wavelength changing
        updateInterval = 0.10.      % Every 100 ms update the wavelength during wavelength change
        hiddenCurrentWavelength=800 % This is the current laser wavelength that is incremented gradually when the user "tunes" the dummy laser 
    end

    methods

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %constructor
        function obj = dummyLaser(~,logObject)
        % function obj = dummyLaser(~,logObject)

            %Attach log object if it is supplied
            if nargin>1
                obj.attachLogObject(logObject);
            end
            obj.controllerID='COMX';
            success = obj.connect;

            obj.maxWavelength=1100;
            obj.minWavelength=700;

            obj.wavelengthTimer = timer;
            obj.wavelengthTimer.Name = 'Dummy laser wavelength updater'
            obj.wavelengthTimer.StartDelay = obj.updateInterval;
            obj.wavelengthTimer.TimerFcn = @(~,~) [] ;
            obj.wavelengthTimer.StopFcn = @(~,~) obj.updateWavelength;
            obj.wavelengthTimer.ExecutionMode = 'singleShot';

            obj.readWavelength; %Initialise currentWavelength to be hiddenCurrentWavelength

            %Set the target wavelength to equal the current wavelength
            obj.targetWavelength=obj.currentWavelength;
            obj.hC.BytesAvailable=0; % Because the laser view checks this before deciding whether to run its timer function
            obj.friendlyName = 'Dummy Laser';
        end %constructor

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        %destructor
        function delete(obj)
            fprintf('Closing dummy laser class\n')
            if isa(obj.wavelengthTimer,'timer')
                stop(obj.wavelengthTimer)
            end
            delete(obj.wavelengthTimer);
        end %destructor

        function success = connect(obj)
            success=true;
            obj.isLaserConnected=success;
        end %connect


        function success = isControllerConnected(obj)
            success=true;
            obj.isLaserConnected=success;
        end

        function success = turnOn(obj)
            success=true;
            obj.isLaserModeLocked=true;
            obj.isLaserOn=true;
        end

        function success = turnOff(obj)
            success=true;
            obj.isLaserModeLocked=false;
            obj.isLaserOn=false;
        end

        function laserOn = isPoweredOn(obj)
            laserOn=obj.isLaserOn;
        end

        function [laserReady,msg] = isReady(obj)
            msg='dummy laser is ready';
            laserReady=true;
            obj.isLaserReady=true;
        end

        function modelockState = isModeLocked(obj)
            modelockState=obj.isLaserModeLocked;
        end

        function success = openShutter(obj)
            obj.isLaserShutterOpen=true;
            success=true;
        end

        function success = closeShutter(obj)
            obj.isLaserShutterOpen=false;
            success=true;
        end

        function [shutterState,success] = isShutterOpen(obj)
            shutterState = obj.isLaserShutterOpen;
            success = true;
        end

        function wavelength = readWavelength(obj) 
            %Get the wavelength from the dummy laser's "internal" state
            wavelength=obj.hiddenCurrentWavelength;
            obj.currentWavelength = wavelength;
        end

        function success = setWavelength(obj,wavelengthInNM)
            success=false;
            if nargin<1
                fprintf('ERROR: Please provide a wavelength to tune to\n')
                return
            end
            if ~isnumeric(wavelengthInNM) || ~isscalar(wavelengthInNM)
                fprintf('ERROR: wavelength should be a numeric scalar\n')
                return 
            end
            if ~obj.isTargetWavelengthInRange(wavelengthInNM)
                return
            end
            if obj.verbose
                fprintf('dummyLaser set wavelength to %0.1f\n', wavelengthInNM);
            end

            obj.targetWavelength = wavelengthInNM;
            start(obj.wavelengthTimer) %Starts the dummy wavelength tunner
            success=true;
        end

        function tuning = isTuning(obj)

            lA = obj.readWavelength;
            pause(0.23)
            lB = obj.readWavelength;

            if lA == lB
                tuning=false;
            else
                tuning=true;
            end

        end

        function laserPower = readPower(~)
            laserPower = 1;
        end

        function laserID = readLaserID(~)
            laserID='dummy_laser'; %Do not edit this line
        end

        function laserStats = returnLaserStats(obj)
            laserStats = sprintf('dummyLaser. Nominal wavelength: %dnm', obj.currentWavelength);
        end

        function success = setWatchDogTimer(~,~)
            success=true;
        end


        % dummy laser specific stuff
        function obj = updateWavelength(obj)
            %Increment current wavelength. If we're still not at the correct wavelength, re-start the timer

            updateStep = obj.nanoMetersPerSecond*obj.updateInterval;
            %Use the hiddenCurrentWavelength property so we don't fire any listeners on obj.currentWavelength.
            %This will mess up the GUI behavior
            updateStep = updateStep * sign(obj.targetWavelength-obj.hiddenCurrentWavelength);
            obj.hiddenCurrentWavelength = round(obj.hiddenCurrentWavelength+updateStep);

            delta = round(obj.hiddenCurrentWavelength-obj.targetWavelength);

            if abs(delta)<=updateStep
                obj.hiddenCurrentWavelength = obj.targetWavelength;
            elseif strcmp(obj.wavelengthTimer.Running,'off')
                start(obj.wavelengthTimer)
            end
        end


    end %close methods

end %close classdef 