classdef (Abstract) laser < handle
%%  laser
%
% The laser abstract class is a software entity that represents the physical
% laser that is used to scan the sample. 
%
% The laser abstract class declares methods and properties that are used by the 
% BakingTray class to check the laser state (is the laser modelocked? is it switched
% on?). The user also interacts with the laser to set and check wavelength and to
% change the shutter state, etc. Classes the control the laser must inherit laser. 
% Objects that inherit laser are "attached" to instances of BakingTray using 
% BakingTray.attachLaser. This method adds an instance of a class that inherits 
% laser to the BakingTray.laser property. 
%
% An example of a class that inherits laser is MaiTai.
%
% Rob Campbell - Basel 2016


    properties 

        hC  %A handle to the hardware object or port (e.g. COM port) used to 
            %control the laser.

        controllerID % The information required by the method that connects to the 
                     % the controller at connect-time. This can be specified in whatever
                     % way is most suitable for the hardware at hand. 
                     % e.g. COM port ID string
        maxWavelength=0 %The longest wavelength the laser can be tuned to in nm
        minWavelength=0 %The longest wavelength the laser can be tuned to in nm
        friendlyName = '' % This string is displayed in the GUI window title. Shouldn't be too long. e.g. could be "MaiTai"

        % The following is used for optional Pockels cell control. An external device
        % may be connected to Pockels cell power to turn the mains power on and off
        % with the laser
        doPockelsPowerControl=false %If true we attempt to gate pockels power with the DAQ
        pockelsDAQ='' % DAQ device ID for gating pockels power. e.g. "Dev1"
        pockelsDigitalLine='' % e.g. 'port0/line2' DO line for pockels cell.
        hDO % Handle to the digital output task
    end %close public properties

    properties (Hidden)
        parent  %A reference of the parent object (likely BakingTray) to which this component is attached
    end %close hidden properties


    % These are GUI-related properties. The view class that comprises the GUI listens to changes in these
    % properties to know when to update the GUI. It is therefore necessary for these to be updated as 
    % appropriate by classes which inherit laser. e.g. If the shutter is opened then the shutterOpen 
    % property must be set to true. Failing to do this will cause the GUI to fail to update. All 
    % properties in this section should be updated in the constructor once the laser is connected
    properties (Hidden, SetObservable, AbortSet)
        isLaserOn=false  % Must be updated by turnOn, turnOff, and isLaserOn
        isLaserShutterOpen=false % True if open. Must be updated by closeShutter, openShutter, and isShutterOpen
        isLaserConnected=false % Set by isControllerConnected
        isLaserModeLocked=false  % Set by isModelocked
        isLaserReady=false % Must be updated by isReady
        currentWavelength=-1 % This must be updated whenever readWavelength runs
        targetWavelength=0 % Must be updated by setWavelength
    end %close GUI-related properties



    % The following are all critical methods that your class should define
    % You should also define a suitable destructor to clean up after you class
    methods (Abstract)
        success = connect(obj)
        % connect
        %
        % Behavior
        % Establishes a connection between the hardware device and the host PC. 
        % The method uses the controllerID property to establish the connection. 
        %
        % Outputs
        % success - true or false depending on whether a connection was established


        success = isControllerConnected(obj)
        % isControllerConnected
        %
        % Behavior
        % Reports whether the link to the laser is functional. This method must update
        % the hidden property isLaserConnected. If the interface, e.g. the COM port
        % is closed, the function must return false. 
        %
        % Outputs
        % success - true or false depending on whether a working connection is present 
        %           with the physical laser device (or whatever device controls it). 
        %           i.e. it is not sufficient that, say, a COM port is open. For success 
        %           to be true, the laser must prove that it can interact in some way 
        %           with the host PC.  


        success = turnOn(obj)
        % turnOn
        %
        % Behavior
        % This is a general-purpose "switch on" command. Most lasers will need to be 
        % turned on in some way or have a software safety interlock disabled. This
        % method should do those things. High power 2-photon lasers tend to have a 
        % built-in physical shutter. This method should not open this if possible. 
        % Use the openShutter method for this purpose. Must update the hidden 
        % property isLaserOn.
        % 
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        success = turnOff(obj)
        % turnOff
        %
        % Behavior
        % This is a general-purpose "switch off" command. Most lasers will need to be 
        % turned off in some way or have a software safety interlock enabled once they are
        % no longer in use. This method is designed to do those things. This method 
        % may or may not close the shutter. This is not important because many lasers
        % will automatically close it when they are turned off. Must update the hidden
        % property isLaserOn.
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded

        [powerOnState,details] = isPoweredOn(obj)
        % isPoweredOn
        %
        % Behavior
        % This function returns true if the laser is powered on or is in the process of
        % powering up. Some lasers will need to warm up for a period of time. The warm
        % up period is classified as powered on. This method should update the hidden
        % property isLaserPoweredOn
        %
        % Outputs
        % powerOnState - true/false. If powered on, set to true.
        % details - optional second argument containing a string with further information



        [laserReady,msg] = isReady(obj)
        % isReady
        %
        % Behavior
        % Returns true if the laser is currently in a state in which it is able to 
        % excite the sample. So it should be, for example, turned on, modelocked,
        % with the shutter open, etc, etc. This command will be called at least
        % once per section. If it returns false the acquisition will stop and wait for
        % user intervention. Updates the hidden property isLaserReady.
        %
        %
        % Outputs
        % laserReady - true/false depending on whether the laser is turned on and ready to go.
        % msg- if the laser is not ready, it should return a string that indicates the 
        %      the reason for the failure. This will be logged or sent as a Slack or 
        %      e-mail message to the operator. 


        modelockState = isModeLocked(obj)
        % isModeLocked
        %
        % Behavior
        % Returns true if the laser is currently modelocked. Returns false otherwise.
        % Updates the hidden property isLaserModeLocked.
        %
        % Outputs
        % modelockState - true/false depending on whether the laser is modelocked


        success = openShutter(obj)
        % openShutter
        %
        % Behavior
        % Running this method should open the laser's built in shutter and return
        % true if the shutter state is now open. This method should use the isShutterOpen
        % method to achieve this. Updates the hidden property isLaserShutterOpen.
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        success = closeShutter(obj)
        % closeShutter
        %
        % Behavior
        % Running this method should close the laser's built in shutter and return
        % true if the shutter state is now closed. This method should use the isShutterOpen
        % method to achieve this. Updates the hidden property isLaserShutterOpen. 
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        shutterState = isShutterOpen(obj)
        % isShutterOpen
        %
        % Behavior
        % Running this method should return true if the laser shutter is open and false otherwise.
        % Returns empty if the shutter state could not be read.  Updates the hidden property isLaserShutterOpen.
        %
        % Outputs
        % shutterState - true or false depending on whether the shutter is open or not


        wavelength = readWavelength(obj)
        % readWavelength
        %
        % Behavior
        % Reads the currently set wavelength of the laser and returns the value as a scalar integer in nm. 
        % It should discard the decimal point. Returns zero if the laser is switched off. 
        % Returns empty if it fails. Updates the hidden property currentWavelength.
        % On failing to read the wavelength, set currentWavelength to zero. 
        %
        % Outputs
        % wavelength - a scalar defining the laser's current wavelength. 


        success = setWavelength(obj, wavelengthInNM)
        % setWavelength
        %
        % Behavior
        % Sets the laser to a new wavelength and updates hidden property targetWavelength
        %
        % Inputs
        % wavelengthInNM - scalar defining wavelength in nm
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        tuning = isTuning(obj)
        % isTuning
        %
        % Behavior
        % Returns true if the laser is currently tuning to a new wavelenth. 
        % Returns false if the laser is at it's set wavelength.
        %
        %
        % Outputs
        % tuning - true/false depending on whether the laser is currently tuning


        laserPower = readPower(obj)
        % readPower
        %
        % Behavior
        % Reads the current laser power and returns the value as a scalar integer in mW.
        % It should discard the decimal point. Returns zero if the laser is switched off. 
        % Returns empty if it fails.
        %
        %
        % Outputs
        % laserPower - a scalar defining the laser's current power in mW.

        success = setWatchDogTimer(obj,timeInSeconds)
        % setWatchDogTimer
        %
        % Behavior
        % The laser's watchdog timer (present on MaiTai lasers, for instance) causes
        % the laser switch off if it has not communicated with the PC for a given 
        % period of time. BakingTray uses this setting to automatically power off
        % the laser should acquisition have stopped in an unexpected way. For example,
        % a hard-crash of MATLAB, a machine reboot, or locking up of the acquisition
        % for some reason. If your laser doesn't have a watchdog timer, you should
        % define this method such that it takes an input argument and returns true. 
        % BakingTray will still be able to turn off the laser if acquisition finishes
        % normally
        %
        % Inputs
        % timeInSeconds - The time-out beyond which the laser powers off. This should
        %                 be comfortably longer than the longest time it might take to
        %                 acquire a section. e.g. 40 minutes should be fine. 



        laserStats = returnLaserStats(obj)
        % returnLaserStats
        %
        % Behavior
        % It's probably not a bad idea to monitor the status of the laser over time. 
        % This is worth doing because running these things 24/7, as we do, is rather
        % hard on them. So we can at least monitor the mood of our laser periodically
        % along with the acquisition of data. This method should simply return a 
        % a string and it's output will just be logged to a file along with other 
        % acquisition progress data. If you don't care about logging laser status 
        % information, you just return an empty string. If you wish to log laser 
        % information then it makes sense to return it in a consistent and machine 
        % readble way. e.g. your string could be:
        % 'outputPower=1700mw,pumpPower=12000mw,wavelength=900nm,humidity=2\n'
        %
        % Avoid "%" signs in your string. They screw up subsequent sprintf lines.
        % You should ensure this method does something. It could be important for the
        % bake cycle.


        laserID = readLaserID(obj)
        % readLaserID
        %
        % Behavior
        % Returns a string that contains the laser serial number, ID, etc. 
        % If your laser has a serial command that returns this information then you
        % may use this. Failing that, you could hard-code the details into the 
        % class or have it read the details from a text file you make. If you really
        % don't care about logging this, then your method should just return the laser
        % model as a string. 
        %
        % You choose...

    end %close abstract methods


    %The following methods are common to all lasers
    methods
        function [inRange,msg] = isTargetWavelengthInRange(obj,targetWavelength)
            %Return false if the target wavelength supplied by the user is
            %out of the allowed range. True otherwise. targetWavelength is
            %defined in nm. 
            if targetWavelength<obj.minWavelength || targetWavelength>obj.maxWavelength
                msg=sprintf('Wavelength %d nm is out of range -- max=%d nm, min=%d nm\n', ...
                    targetWavelength, obj.maxWavelength, obj.minWavelength);
                sprintf(msg);
                inRange=false;
                return
            end
            msg='';
            inRange=true;
        end

        function connectToPockelsControlDAQ(obj)
            % Connect to NI DAQ that will control Pockels power
            if ~isempty(obj.pockelsDAQ) && ischar(obj.pockelsDAQ) && ... 
                ~isempty(obj.pockelsDigitalLine) && ischar(obj.pockelsDigitalLine)
                % Try to connect to the Pockels cell DAQ
                try
                    obj.hDO = dabs.ni.daqmx.Task('laserpockels');
                    obj.hDO(1).createDOChan(obj.pockelsDAQ, obj.pockelsDigitalLine); %Open one digital line
                catch ME
                    fprintf('\nLaser failed to connect to Pockels DAQ\n')
                    disp(ME.message)
                    obj.hDO = [];
                end

            end
        end % connectToPockelsControlDAQ

        function switchPockelCell(obj)
            % Gate pockels cell based on the reported power state of the laser
            % This method can be called from methods that turn on or turn off the 
            % laser. It is not a callback. 
            if isempty(obj.hDO) || ~obj.doPockelsPowerControl
                return 
            end

            if obj.isLaserOn
                obj.hDO.writeDigitalData(1)
            else
                obj.hDO.writeDigitalData(0)
            end
        end % switchPockelCell


    end %close methods

end %close classdef
