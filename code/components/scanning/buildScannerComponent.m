function component = buildScannerComponent(componentName,scannerSettings)
% Build scanner component from a scanner class and return object
%
%
%   function buildScannerComponent(componentName,scannerSettings)
%
%
% Purpose
% Construct a scanner component object from one of the available classes,
% feeding in whatever input arguments are necessary. Returns the constructed
% object. This function used during setup of BakingTray.
%
% Inputs
% componentName - string defining the name of the class to build
% scannerSettings - whatever input arguments are needed by the class to be built. 
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

if nargin<2
    scannerSettings=[];
end

validComponents = {'dummyScanner','SIBT'}; %The available scanner components
validComponentSuperClassName = 'scanner'; %The name of the abstract class that all scanner components must inherit



%Build the correct object based on "componentName"
switch componentName
    case 'dummyScanner'
        component = dummyScanner;
    case 'SIBT'
        %Look for ScanImage and only proceed if it's present
        W = evalin('base','whos');
        
        if ~ismember('hSI',{W.name})
            pathToSI = which('scanimage');
            if isempty(pathToSI)
                fprintf('ScanImage is not installed.\n')
                fprintf('SKIPPING CONSTRUCTION OF SCANNER COMPONENT.\n')
                component=[];
                return
            end
            % Start ScanImage
            scanimage
        end
        
        fprintf('Connecting to scanner\n')
        component=SIBT;

    otherwise
        fprintf('ERROR: unknown scanner component "%s" SKIPPING BUILDING\n', componentName)
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

