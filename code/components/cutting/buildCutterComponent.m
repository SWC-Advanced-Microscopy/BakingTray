function component = buildCutterComponent(componentName,varargin)
% Build cutter component from a cutter class and return object
%
%
%   function buildCutterComponent(componentName,varargin)
%
%
% Purpose
% Construct a cutter hardware component object from one of the available classes,
% feeding in whatever input arguments are necessary. Returns the constructed
% object. This function used during setup of BakingTray.
%
% Inputs
% componentName - string defining the name of the class to build
% vargargin - whatever input arguments are needed by the class to be built. 
%             may just be a COM port string. These could differ between classes.
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


validComponents = {'dummyCutter','FaulhaberMCDC'}; %The available cutter components
validComponentSuperClassName = 'cutter'; %The name of the abstract class that all cutter components must inherit



%Build the correct object based on "componentName"
switch componentName
    case 'dummyCutter'
        component = dummyCutter;
    case 'FaulhaberMCDC'
        COMPORT = BakingTray.settings.parseComPort(varargin{1});
        component = FaulhaberMCDC(COMPORT);
    otherwise
        fprintf('ERROR: unknown cutter component "%s" SKIPPING BUILDING\n', componentName)
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

