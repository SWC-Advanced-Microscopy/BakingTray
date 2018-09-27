% Most Software Machine Data File
% Simulated MDF for BakingTray with linear scanners
%% ScanImage

%Global microscope properties
objectiveResolution = 60;           % Resolution of the objective in microns/degree of scan angle

%Scanner systems
scannerNames = {'LinScanner'};      % Cell array of string names for each scan path in the microscope
scannerTypes = {'Linear'};        % Cell array indicating the type of scanner for each name. Current options: {'Resonant' 'Linear' 'SLM'}

%Simulated mode
simulated = true;                  % Boolean for activating simulated mode. For normal operation, set to 'false'. For operation without NI hardware attached, set to 'true'.

%Optional components
components = {'dabs.generic.GenericPmtController'};                    % Cell array of optional components to load. Ex: {'dabs.thorlabs.ECU1' 'dabs.thorlabs.BScope2'}

%Data file location
dataDir = '[MDF]\ConfigData';       % Directory to store persistent configuration and calibration data. '[MDF]' will be replaced by the MDF directory

startUpScript = '';

%% Shutters
%Shutter(s) used to prevent any beam exposure from reaching specimen during idle periods. Multiple
%shutters can be specified and will be assigned IDs in the order configured below.
shutterNames = {'Main Shutter'};    % Cell array specifying the display name for each shutter eg {'Shutter 1' 'Shutter 2'}
shutterDaqDevices = {'aux1'};  % Cell array specifying the DAQ device or RIO devices for each shutter eg {'PXI1Slot3' 'PXI1Slot4'}
shutterChannelIDs = {'PFI12'};      % Cell array specifying the corresponding channel on the device for each shutter eg {'PFI12'}

shutterOpenLevel = true;               % Logical or 0/1 scalar indicating TTL level (0=LO;1=HI) corresponding to shutter open state for each shutter line. If scalar, value applies to all shutterLineIDs
shutterOpenTime = 0.1;              % Time, in seconds, to delay following certain shutter open commands (e.g. between stack slices), allowing shutter to fully open before proceeding.

%% Beams
beamDaqDevices = {};                            % Cell array of strings listing beam DAQs in the system. Each scanner set can be assigned one beam DAQ ex: {'PXI1Slot4'}

% Define the parameters below for each beam DAQ specified above, in the format beamDaqs(N).param = ...
beamDaqs(1).modifiedLineClockIn = '';           % one of {PFI0..15, ''} to which external beam trigger is connected. Leave empty for automatic routing via PXI/RTSI bus
beamDaqs(1).frameClockIn = '';                  % one of {PFI0..15, ''} to which external frame clock is connected. Leave empty for automatic routing via PXI/RTSI bus
beamDaqs(1).referenceClockIn = '';              % one of {PFI0..15, ''} to which external reference clock is connected. Leave empty for automatic routing via PXI/RTSI bus
beamDaqs(1).referenceClockRate = 10e6;          % if referenceClockIn is used, referenceClockRate defines the rate of the reference clock in Hz. Default: 10e6Hz

beamDaqs(1).chanIDs = [];                       % Array of integers specifying AO channel IDs, one for each beam modulation channel. Length of array determines number of 'beams'.
beamDaqs(1).displayNames = {};                  % Optional string cell array of identifiers for each beam
beamDaqs(1).voltageRanges = 1.5;                % Scalar or array of values specifying voltage range to use for each beam. Scalar applies to each beam.

beamDaqs(1).calInputChanIDs = [];               % Array of integers specifying AI channel IDs, one for each beam modulation channel. Values of nan specify no calibration for particular beam.
beamDaqs(1).calOffsets = [];                    % Array of beam calibration offset voltages for each beam calibration channel
beamDaqs(1).calUseRejectedLight = false;        % Scalar or array indicating if rejected light (rather than transmitted light) for each beam's modulation device should be used to calibrate the transmission curve 
beamDaqs(1).calOpenShutterIDs = [];             % Array of shutter IDs that must be opened for calibration (ie shutters before light modulation device).

%% Motors
%Motor used for X/Y/Z motion, including stacks. 

motors(1).controllerType = '';           % If supplied, one of {'sutter.mp285', 'sutter.mpc200', 'thorlabs.mcm3000', 'thorlabs.mcm5000', 'scientifica', 'pi.e665', 'pi.e816', 'npoint.lc40x'}.
motors(1).dimensions = '';               % Assignment of stage dimensions to SI dimensions. Can be any combination of X,Y,Z, and R.
motors(1).comPort = [];                  % Integer identifying COM port for controller, if using serial communication
motors(1).customArgs = {};               % Additional arguments to stage controller. Some controller require a valid stageType be specified
motors(1).invertDim = [];                % string with one character for each dimension specifying if the dimension should be inverted. '+' for normal, '-' for inverted
motors(1).positionDeviceUnits = [];      % 1xN array specifying, in meters, raw units in which motor controller reports position. If unspecified, default positionDeviceUnits for stage/controller type presumed.
motors(1).velocitySlow = [];             % Velocity to use for moves smaller than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.
motors(1).velocityFast = [];             % Velocity to use for moves larger than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.
motors(1).moveCompleteDelay = 0;        % Delay from when stage controller reports move is complete until move is actually considered complete. Allows settling time for motor
motors(1).moveTimeout = [];              % Default: 2s. Fixed time to wait for motor to complete movement before throwing a timeout error
motors(1).moveTimeoutFactor = [];        % (s/um) Time to add to timeout duration based on distance of motor move command

%% FastZ
%FastZ hardware used for fast axial motion, supporting fast stacks and/or volume imaging

actuators(1).controllerType = 'simulated.piezo';           % If supplied, one of {'pi.e665', 'pi.e816', 'npoint.lc40x', 'analog'}.
actuators(1).comPort = 1;                  % Integer identifying COM port for controller, if using serial communication
actuators(1).customArgs = {};               % Additional arguments to stage controller
actuators(1).daqDeviceName = 'aux1';            % String specifying device name used for FastZ control
actuators(1).frameClockIn = '';             % One of {PFI0..15, ''} to which external frame trigger is connected. Leave empty for automatic routing via PXI/RTSI bus
actuators(1).cmdOutputChanID = 0;          % AO channel number (e.g. 0) used for analog position control
actuators(1).sensorInputChanID = [];        % AI channel number (e.g. 0) used for analog position sensing
actuators(1).commandVoltsPerMicron = 0.025;    % Conversion factor for desired command position in um to output voltage
actuators(1).commandVoltsOffset = 0;        % Offset in volts for desired command position in um to output voltage
actuators(1).sensorVoltsPerMicron = 0.025;     % Conversion factor from sensor signal voltage to actuator position in um. Leave empty for automatic calibration
actuators(1).sensorVoltsOffset = 0;        % Sensor signal voltage offset. Leave empty for automatic calibration
actuators(1).maxCommandVolts = 10;          % Maximum allowable voltage command
actuators(1).maxCommandPosn = 400;           % Maximum allowable position command in microns
actuators(1).minCommandVolts = -10;          % Minimum allowable voltage command
actuators(1).minCommandPosn = -400;           % Minimum allowable position command in microns
actuators(1).optimizationFcn = [];          % Function for waveform optimization
actuators(1).affectedScanners = {};         % If this actuator only changes the focus for an individual scanner, enter the name

%% LinScan (LinScanner)
deviceNameAcq = 'scan';      % string identifying NI DAQ board for PMT channels input
deviceNameGalvo = 'scan';      % string identifying NI DAQ board for controlling X/Y galvo. leave empty if same as deviceNameAcq
deviceNameAux = 'aux1';      % string identifying NI DAQ board for outputting clocks. leave empty if unused. Must be a X-series board

%Optional
channelsInvert = [false false false false];             % scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels
beamDaqID = [];                     % Numeric: ID of the beam DAQ to use with the linear scan system
shutterIDs = 1;                     % Array of the shutter IDs that must be opened for linear scan system to operate

referenceClockIn = '';              % one of {'',PFI14} to which 10MHz reference clock is connected on Aux board. Leave empty for automatic routing via PXI bus
enableRefClkOutput = 0;         % Enables/disables the export of the 10MHz reference clock on PFI14

%Acquisition
channelIDs = [0 1 2 3];                    % Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)

%Scanner position feedback
deviceNameGalvoFeedback = '';       % string identifying NI DAQ board that reads the galvo position feedback signals. Leave empty if they are on deviceNameGalvo. Cannot be the same as deviceNameAcq when using for line scanning
XMirrorPosChannelID = [];           % The numeric ID of the Analog Input channel to be used to read the X Galvo position (optional).
YMirrorPosChannelID = [];           % The numeric ID of the Analog Input channel to be used to read the y Galvo position (optional).

%Scanner control
XMirrorChannelID = 0;               % The numeric ID of the Analog Output channel to be used to control the X Galvo.
YMirrorChannelID = 1;               % The numeric ID of the Analog Output channel to be used to control the y Galvo.

xGalvoAngularRange = 15;            % max range in optical degrees (pk-pk) for x galvo
yGalvoAngularRange = 15;            % max range in optical degrees (pk-pk) for y galvo

voltsPerOpticalDegreeX = 1;         % galvo conversion factor from optical degrees to volts (negative values invert scan direction)
voltsPerOpticalDegreeY = 1;         % galvo conversion factor from optical degrees to volts (negative values invert scan direction)

scanParkAngleX = -7.5;              % Numeric [deg]: Optical degrees from center position for X galvo to park at when scanning is inactive
scanParkAngleY = -7.5;              % Numeric [deg]: Optical degrees from center position for Y galvo to park at when scanning is inactive

%Optional: mirror position offset outputs for motion correction
deviceNameOffset = '';              % string identifying NI DAQ board that hosts the offset analog outputs
XMirrorOffsetChannelID = 0;         % numeric ID of the Analog Output channel to be used to control the X Galvo offset.
YMirrorOffsetChannelID = 1;         % numeric ID of the Analog Output channel to be used to control the y Galvo offset.

XMirrorOffsetMaxVoltage = 1;        % maximum allowed voltage output for the channel specified in XMirrorOffsetChannelID
YMirrorOffsetMaxVoltage = 1;        % maximum allowed voltage output for the channel specified in YMirrorOffsetChannelID

internalRefClockSrc = '';

LaserTriggerPort = '';

%% Photostim
photostimScannerName = '';     % Name of scanner (from first MDF section) to use for photostimulation. Must be a linear scanner

% Monitoring DAQ AI channels
BeamAiId = 0;     % AI channel to be used for monitoring the Pockels cell output

loggingStartTrigger = '';     % one of {'','PFI#'} to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus

%% IntegrationRoiOutputs
channelNames = {'Software'};     % User defined name for each output channels e.g. {'My first channel','My second channel','My third channel'}
deviceNames = {'none'};     % Names of DAQ device for each channel, use 'none' if no physical device is used e.g. {'Dev1','Dev1','none'}
deviceChannels = {'none'};     % Channel index for each channel: numeric values for analog outputs, strings for digital outputs, use 'none' for software output; e.g {0, 'port0/line0', 'none'} for AO0, port0/line0 and a software output

%% GenericPmtController
pmtNames = {'Far Red' 'Red' 'Green' 'Blue'};     % cell array of names for PMTs e.g.

pmtDaqDeviceName = {'pmt' 'pmt' 'pmt' 'pmt'};     % cell array of NI-DAQ devices to control each PMT channel. If only one device is given, all channels will be mapped onto that one device
pmtDaqGainAOChannels = [0 1 2 3];     % <optional> array of numeric analog output channel IDs to control the gain for each PMT; if set to empty array, functionality is disabled
pmtDaqPowerDOChannels = {'port0/line0' 'port0/line1' 'port0/line2' 'port0/line3'};     % <optional> cell array of strings specifying the digital port name to switch each PMT on/off; if set to empty cell array, functionality is disabled
pmtDaqTrippedDIChannels = {'' '' '' ''};     % <optional> cell array of strings specifying the digital port name to detect the trip status for each PMT; if set to empty cell array, functionality is disabled
pmtDaqTripResetDOChannels = {'' '' '' ''};     % <optional> cell array of strings specifying the digital port name to reset the trip status for each PMT; if set to empty cell array, functionality is disabled

pmtDaqAOVoltageRange = {[0 5] [0 5] [0 5] [0 5]};     % <required if pmtDaqGainAOChannels is defined> cell array of 1x2 numeric array specifying the minimum and maximum analog output voltage on the NI-DAQ board that controls the PMT gain. If only one numeric array is given, this value is used for all PMT channels
pmtMaxGainValue = [1250 1250 1250 1250];     % <required if pmtDaqGainAOChannels is defined> array specifying the maximum display value for the PMT gain. If only one value is given, this value is used for all PMT channels

