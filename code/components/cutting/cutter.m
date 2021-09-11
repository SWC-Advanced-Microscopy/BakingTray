classdef (Abstract) cutter < handle
%%  cutter
%
% The cutter abstract class is a software entity that represents the physical
% vibrotome that removes slices from the tissue block being imaged. 
%
% The cutter abstract class declares methods and properties that are used by the 
% BakingTray class to start and stop the vibrotome. Classes the control the vibrotome
% must inherit cutter. Objects that inherit cutter are "attached" to instances of 
% BakingTray using BakingTray.attachCutter. This method adds an instance of a class
% that inherits cutter to the BakingTray.cutter property. 
%
% An example of a class that inherits cutter is FaulhaberMCDC.
%
% Rob Campbell - Basel 2016


    properties 

        hC  %A handle to the hardware object or port (e.g. COM port) used to 
            %control the cutter.

        controllerID % The information required by the method that connects to the 
                     % the controller at connect-time. This can be specified in whatever
                     % way is most suitable for the hardware at hand. 
                     % e.g. COM port ID string
    end %close public properties

    properties (Hidden, SetObservable, AbortSet)
        isCutterConnected=false  % Must be updated by connect and isControllerConnected
        kickOffSection=false     % If true, the slicing code will execute a sharp forward 
                                 % motion of the blade once it's cut through the block.
    end
    properties (Hidden)
        parent  %A reference of the parent object (likely BakingTray) to which this component is attached
    end 


    % These are GUI-related properties. The view classes listen to changes in these properties
    % to know when to update the GUI.
    properties (Hidden, SetObservable, AbortSet)
        isCutterVibrating=false  % Must be updated by turnOn and turnOff
    end

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
        % Reports whether the link to the cutter controller is functional. This method
        % must update the hidden property isCutterConnected. If the interface, e.g. 
        % the COM port closed, the function must return false. 
        %
        % Outputs
        % success - true or false depending on whether a working connection is present 
        %           with the physical vibrotome control device. i.e. it is not sufficient 
        %           that, say, a COM port is open. For success to be true, the device must
        %           prove that it can interact in some way with the host PC. 


        success = enable(obj)
        % enable
        %
        % Behavior
        % This is a general-purpose "arm" command. Some hardware or controllers will need
        % need to be enabled before they move. This ensures that this happens. If the 
        % controller or motor does not support or require this, this method should simply
        % return true.
        %
        % Outputs
        % success - true or false depending on whether the command succeeded


        success = disable(obj)
        % disable
        %
        % Behavior
        % This is a general-purpose "disarm" command. Some hardware or controllers have 
        % the option to be disabled. This is distinct from stopping of motion. e.g. 
        % disabling may power down the device. If the controller or motor does not 
        % support or require this, this method should simply return true. 
        %
        %
        % Outputs
        % success - true or false depending on whether the command succeeded



        success = startVibrate(obj,cyclesPerSec)
        % startVibrate
        %
        % Behavior
        % Vibrate blade at cyclesPerSec rate. i.e. cyclesPerSec = RPM * 60 
        % Begins vibration and returns true if vibration command was sent
        % successfully. Returns false otherwise. Non-blocking. If blade is already
        % vibrating when the method is called then this function should update vibration
        % frequency. 
        %
        %
        % Inputs
        % cyclesPerSec - numeric scalar defining how many cycles per second the blade
        %                should vibrate at.
        %
        % Outputs
        % success - true or false depending on whether the command succeeded



        success = stopVibrate(obj)
        % stopVibrate
        %
        % Behavior
        % Stops vibration of the blade.
        %
        % Outputs
        % success - true or false depending on whether the command succeededp



        cyclesPerSec = readVibrationSpeed(obj)
        % readVibrationSpeed
        %
        % Behavior
        % Returns the vibration speed of the blade as read from a sensor, such as an
        % encoder. Not all hardware support this. Returns false if such a reading 
        % can not be obtained.
        % 
        % Output
        % cyclesPerSec - Measured vibration speed in cycles per second. False if no such
        %                reading can be made. i.e. this method never simply returns the
        %                commanded vibration frequency.

    end %close methods

end %close classdef 