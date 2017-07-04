function component = buildScannerComponent(componentName,varargin)
% Build scanner component from a scanner class and return object
%
%
%   function buildScannerComponent(componentName,varargin)
%
%
% Purpose
% Construct a scanner component object from one of the available classes,
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


validComponents = {'dummyScanner','SIBT'}; %The available scanner components
validComponentSuperClassName = 'scanner'; %The name of the abstract class that all scanner components must inherit



%Build the correct object based on "componentName"
switch componentName
    case 'dummyScanner'
        component = dummyScanner;
    case 'SIBT'
        %Look for ScanImage and only proceed if it's present
        W = evalin('base','whos');
        if ismember('hSI',{W.name});
            fprintf('Connecting to scanner\n')
            component=SIBT;
        else
            fprintf('No instance of ScanImage started. SKIPPING CONSTRUCTION OF SCANNER COMPONENT.\n')
            fprintf('To attach ScanImage to BakingTray you should:\n')
            fprintf(' 1) start scanimage\n')
            fprintf(' 2) run "hBT.attachScanner"\n')
            component=[];
            return
        end
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

