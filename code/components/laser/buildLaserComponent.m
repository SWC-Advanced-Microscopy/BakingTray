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


if ~ischar(componentName)
    fprintf('%s - argument "componentName" should be a string. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
    component=[];
    return
end


validComponentSuperClassName = 'laser'; %The name of the abstract class that all laser components must inherit


%Build the correct object based on "componentName"
switch componentName
    case 'dummyLaser'
        component = dummyLaser;
    case 'maitai'
        COMPORT = BakingTray.settings.parseComPort(varargin{1});
        component = maitai(COMPORT);
    case 'chameleon'
        COMPORT = BakingTray.settings.parseComPort(varargin{1});
        component = chameleon(COMPORT);
        return
    otherwise
        fprintf('ERROR: unknown laser component "%s" SKIPPING BUILDING\n', componentName)
        component=[];
        return
end


% Do not return component if it's not of the correct class. 
% e.g. this can happen if the class doesn't inherit the correct abstract class
if ~isa(component,validComponentSuperClassName)
    fprintf('ERROR: constructed component %s is not of class %s. SKIPPING BUILDING.\n', ...
     componentName, validComponentSuperClassName);
    delete(component) %To clean up any open ports, etc
    component = [];
end

