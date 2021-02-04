function component = buildMotionComponent(controllerName,controllerParams,varargin)
% Build  motion component
%
%   function buildMotionComponent(controllerName,controllerParams,stageName1,stageParams1,...stageNameN,stageParamsN)
%
%
% Purpose
% Construct a motion hardware component object from one of the available classes,
% feeding in whatever input arguments are necessary. Returns the constructed
% motion object incorporating both a linearcontroller and one or more linearstages. 
% This function used during setup of BakingTray.
%
% Inputs
% controllerName    - string defining the name of the class to build
% controllerParams  - a structure containing the settings to be applied to the controller 
% stageName         - a string defining the name of the stage class to attach to the controller
% stageParams       - a structure containing the settings to be applied to the stage
% 
% multiple stage/params can be added to a single controller
%
%
% Outputs
% component - A composite motion component object comprised of a stage controller 
%             with attached stages. This object has class "linearcontroller"
%
%
%
% Rob Campbell, Basel - 2016


if nargin<4
    fprintf('%s needs at least four input arguments. QUITTING\n',mfilename)
    return
end

if ~ischar(controllerName)
    fprintf('%s - argument "controllerName" should be a string. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
    component=[];
    return
end

if ~isstruct(controllerParams)
    fprintf('%s - argument "controllerParams" should be a structure. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
    component=[];
    return
end

if ~isfield(controllerParams,'connectAt')
    fprintf('%s - second argument should be the  controller connection parameters. SKIPPING CONSTRUCTION OF COMPONENT\n', mfilename)
end


if mod(length(varargin),2) ~= 0
    fprintf('Stage input aruments should come in pairs. e.g. -\n{''myStage'',struct(''minPos'',-10,''maxPos'',10)\n')
    fprintf('see "help buildMotionComponent" and the BakingTray documentation for more details\n')
    return
end
stages = reshape(varargin,2,[])'; %so each row is one stage .


% The available controller components 
controllerSuperClassName = 'linearcontroller'; %The name of the abstract class that all controller components must inherit



%Build the correct object based on "controllerName"
component = [];
switch controllerName
    case 'BSC201_APT'
        % Likely this will be used to control the Z-stage
        stageComponents = BUILD_GENERIC_STAGE(stages);
        if isempty(stageComponents)
            return
        end

        component = BSC201_APT(stageComponents);
        component.connect([],0); %Connect to the controller with a new figure window
        component.hC.SetBLashDist(0,0);  %switch off backlash compensation
        %The following are reasonable settings that avoid stepper motor slipping even under load
        component.setAcceleration(0.5);
        component.setMaxVelocity(2);

    case {'C891', 'C663', 'C863'}
        % Likely this will be used to control an X or Y stage
        stageComponents = BUILD_GENERIC_STAGE(stages);
        if isempty(stageComponents)
            return
        end

        %TODO - likely all controllers can be done as below and we get rid of switch statement
        component = eval([controllerName,'(stageComponents)']);

        controllerID = controllerParams.connectAt;
        controllerID.controllerModel=strrep(controllerName,'C','C-');

        component.connect(controllerID); %Connect to the controller

    case 'AMS_SIN11'
        % Likely used to control Z stage
        stageComponents = BUILD_GENERIC_STAGE(stages);
        if isempty(stageComponents)
            return
        end
        component = AMS_SIN11(stageComponents);
        component.connect(controllerParams.connectAt);
    case 'ensemble'
        stage=generic_AeroTechZJack;
        stage.axisName = varargin{1,2}.axisName;
        component = ensemble(stage);
%         component = eval([controllerName,'(stageComponents)']);
        controllerID = controllerParams.connectAt;
        component.connect(controllerID);
    case 'soloist'
        stageComponents = BUILD_GENERIC_STAGE(stages);
        if isempty(stageComponents)
            return
        end
        
        component = eval([controllerName,'(stageComponents)']);
        controllerID = controllerParams.connectAt;
        component.connect(controllerID)
        
    case 'dummy_linearcontroller'
        stageComponents = BUILD_GENERIC_STAGE(stages);
        component = dummy_linearcontroller(stageComponents);

    case 'analog_controller'
        % This could be used to control a PIFOC, say
        fprintf('NO ANALOG CONTROLLERS AT PRESENT\n')
        fprintf('NO SETUP ROUTINE YET FOR "analog_controller"\n')

    otherwise
        fprintf('ERROR: unknown motion controller component "%s" SKIPPING BUILDING\n', controllerName)
        component=[];
        return

end


% Do not return component if it's not of the correct class. 
% e.g. this can happen if the class doesn't inherit the correct abstract class
if ~isa(component,controllerSuperClassName)
    fprintf('ERROR in %s:\n constructed component %s is not of class %s. It is a %s. SKIPPING BUILDING.\n', ...
     mfilename, controllerName, controllerSuperClassName, class(component));
    delete(component) %To clean up any open ports, etc
end




%----------------------------------------------------------------------------------------------------
function stageComponents = BUILD_GENERIC_STAGE(stages)
    % This function is used to create a stage component that can be attached to a linearController. 
    % This generic function is designed to work with most stages. If you need something very 
    % specific then you might need to write a new build sub-function for your particular device. 
    % Hopefully, however, all customisation can be done within the stage and controller classes
    % and in the componentSettings script. 

    if size(stages,1)>1
        error('BUILD_GENERIC_STAGE can not yet handle multiple stages per controller')
    end

    stageComponents=[]; % In case function ends prematurely
    stageComponentName = stages{1,1}; %Should be the name of a valid class in the path
    stageSettings = stages{1,2};

    if ~checkArgs(stageComponentName,stageSettings)
        return
    end

    stageComponents = eval(stageComponentName);

    %User settings 
    % TODO - deal with multiple stages
    settingsFields = fields(stageSettings);
    for ii=1:length(settingsFields)
        tField = settingsFields{ii};
        if ~isprop(stageComponents,tField)
            fprintf('Stage %s has no property %s. Skipping this setting.\n', ...
            stageComponentName,tField );
            continue
        end
        if isempty(stageSettings.(tField))
            continue
        end
        stageComponents.(tField) = stageSettings.(tField);
    end


function success = checkArgs(stageComponentName,stageSettings)
    % Check whether the stageComponent name and stageSettings structure are correct. 
    % i.e. are they the right type and do they look like they contain plausible contents
    if ~ischar(stageComponentName)
        fprintf('Can not build stage. Stage component name is a %s. Expected a string\n', class(stageComponentName))
        success=false;
        return
    end

    if ~isstruct(stageSettings)
        fprintf('Can not build stage. Stage component settings is a %s. Expected a structure\n', class(stageSettings))
        success=false;
        return
    end

    if ~exist(stageComponentName,'file')
        fprintf('Can not find the stage component class %s in the MATLAB path\n', stageComponentName)
        success=false;
        return
    end

    if ~isfield(stageSettings,'axisName') || ~isfield(stageSettings,'minPos') || ~isfield(stageSettings,'maxPos') 
        fprintf('%s - stageSettings of %s do not appear valid: \n',mfilename,stageComponentName)
        disp(stageSettings)
        fprintf('Settings must at least have fields: axisName, minPos, and maxPos\n')
        fprintf('QUITTING\n')
        success=false;
        return
    end

    success=true;
