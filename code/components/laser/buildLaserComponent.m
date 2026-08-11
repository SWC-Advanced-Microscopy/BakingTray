function component = buildLaserComponent(componentName,varargin)
% Build laser component from a laser class and return object
%
%
%   function buildLaserComponent(componentName,componentSettings)
%
%
% Purpose
% Construct a laser hardware component object from one of the available classes,
% feeding in whatever input arguments are necessary. Returns the constructed
% object. This function used during setup of BakingTray.
%
% Inputs
% componentName - string defining the name of the class to build
% componentSettings - one or more input arguments describing the componentSettings
%              needed to connect to the device. May just be a COM port string. 
%              These could differ between classes.
%
%
% Outputs
% component - the component object. empty in the event of an error.
%
%
% Basel - 2016
%
% See alseo: BT.attachLaser


if ~ischar(componentName)
    fprintf('%s - argument "componentName" should be a string. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
    component=[];
    return
end


validComponentSuperClassName = 'laser'; %The name of the abstract class that all laser components must inherit

laserSettings = varargin{1};
COMPORT = BakingTray.settings.parseComPort(laserSettings.COM);

% The wavelength field is new (2026/08/11) and optional. It is only used by lasers which
% can not report their own wavelength over serial, such as the Axon. Tunable lasers read
% the wavelength from the hardware and ignore it.
if ~isfield(laserSettings,'wavelength')
    laserSettings.wavelength=[];
end

%Build the correct object based on "componentName"
switch componentName
    case 'dummyLaser'
        component = dummyLaser;
     case 'tiberius'
        component = tiberius(COMPORT);
    case 'maitai'
        component = maitai(COMPORT);
    case 'chameleon'
        component = chameleon(COMPORT);
    case 'axon'
        component = axon(COMPORT);
        % The Axon is fixed-wavelength and can not report its wavelength, so the settings
        % file has to state it. This also sets the friendlyName. e.g. "Axon-1064"
        component.setFixedWavelength(laserSettings.wavelength);
    otherwise
        fprintf('ERROR: unknown laser component "%s" SKIPPING BUILDING\n', componentName)
        component=[];
        return
end

% Say so if a wavelength was defined for a laser which reads its wavelength from the
% hardware, so the user is not left wondering why it had no effect.
if ~isempty(laserSettings.wavelength) && ~strcmp(componentName,'axon')
    fprintf(['NOTE: the laser "%s" reads its wavelength from the hardware, so the wavelength\n', ...
        'defined for it in the component settings file is ignored.\n'], componentName)
end


% Do not return component if it's not of the correct class.
% e.g. this can happen if the class doesn't inherit the correct abstract class
if ~isa(component,validComponentSuperClassName)
    fprintf('ERROR: constructed component %s is not of class %s. SKIPPING BUILDING.\n', ...
     componentName, validComponentSuperClassName);
    delete(component); %To clean up any open ports, etc
    component = [];
end



% Fill in the beamName value used to associate the laser with a beam line
% ScanImage.
component.beamName = laserSettings.beamName;

%If requested, we connect to the pockels cell
% TODO -- for now we place this here. Later maybe move to the laser classes
if ~isempty(laserSettings.pockels)
    fprintf('%s is connecting to Pockels cell power gating\n',mfilename);
    component.pockelsDAQ = laserSettings.pockels.pockelsDAQ;
    component.pockelsDigitalLine = laserSettings.pockels.pockelsDigitalLine;
    component.doPockelsPowerControl = laserSettings.pockels.doPockelsPowerControl;
    component.connectToPockelsControlDAQ;
end

