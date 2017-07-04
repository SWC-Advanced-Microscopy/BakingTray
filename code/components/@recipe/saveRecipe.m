function success=saveRecipe(obj,recipeFname)
    % Write the core recipe fields to disk as the file "recipeFname"
    % 
    % recipe.saveRecipe
    %
    % Purpose
    % Writes only the core settings to a a defined location. This is used to save modified
    % recipe files for re-use later. i.e. we save only the sample and mosaic fields not 
    % things like the front-left position which are highly sample-specific. The sample ID 
    % is wiped. The purpose of this function is to save a clean recipe for re-use to build
    % a new acquisition. 
    %
    % 
    % Inputs
    % recipeFname - path to file location
    % 
    % Outputs
    % success - returns true if the file was written. false otherwise
    %
    % Also see:
    %  recipe.writeFullRecipeForAcquisition

    success=false;

    if nargin<2
        fprintf('ERROR: No save file locatio suppled to recipe.saveRecipe\n');
        return
    end

    [pathToFileLocation,thisFname,ext] = fileparts(recipeFname);

    if isempty(pathToFileLocation)
        %Then it must be the current directory
        pathToFileLocation=pwd;
    end

    if exist(pathToFileLocation,'dir')~=7 
        %Then it's not a valid director
        fprintf('ERROR: recipe.saveRecipe can not find directory %s. Not saving.\n',pathToFileLocation)
        return
    end

    %Build a save file name (e.g. adding an extension if one was missing)
    recipeFname = fullfile(pathToFileLocation,[thisFname,'.yml']);

    %Build the structure we will save
    thisRecipe.sample = obj.sample;
    thisRecipe.sample.ID = ''; %Wipe the sample name, a new generic name will be created by the recipe setter
    thisRecipe.mosaic = obj.mosaic;


    %Write to disk and check it's there
    BakingTray.yaml.WriteYaml(recipeFname,thisRecipe);

    if exist(recipeFname,'file')
        success=true;
    end
