function varargout=writeFullRecipeForAcquisition(obj,dirName)
    % Write recipe to disk and name it according to the sample ID and today's date
    % 
    % recipe.writeFullRecipeForAcquisition(dirName)
    %
    % Purpose
    % Turns all the public properties of the recipe class into a structure containing
    % their current values and writes this to disk in the current directory as a file
    % named: "recipe_SAMPLENAME_YYMMDD.yml" This operation is performed at the start
    % of data acquisition in order to record the parameters with whihc the acquisition
    % was performed. The purpose of this method is to create a recipe file that can be
    % used to run, re-run, or re-start a specific acquisition.
    %
    % 
    % Inputs
    % dirName - By default the recipe is written to the current directory. If dirName
    %           is defined, the recipe is written here instead. 
    %
    % Outputs
    % Optionally return the full path to the file location
    %
    %
    % Also see:
    %  recipe.saveRecipe 

    if nargin<2
        dirName=pwd;
    end

    thisRecipe = obj.recipe2struct;

    recipeFname = sprintf('recipe_%s_%s.yml',obj.sample.ID,datestr(now,'yymmdd_HHMMSS'));

    %We call tile pattern to ensure that the recipe parameters are up to date. This may no longer be needed.
    obj.tilePattern; %TODO: ensure we no longer need this explicit call here. 

    writePath = fullfile(dirName,recipeFname);
    fprintf('Writing recipe to %s\n',writePath);
    BakingTray.yaml.WriteYaml(writePath,thisRecipe);

    if nargout>0
        varargout{1}=writePath;
    end
