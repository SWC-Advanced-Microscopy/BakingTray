function varargout=writeFullRecipeForAcquisition(obj,dirName,forceWrite)
    % Write recipe to disk and name it according to the sample ID and today's date
    % 
    % recipe.writeFullRecipeForAcquisition(dirName,forceWrite)
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
    % forceWrite - by default we do not write if a recipe already exists in the same
    %           path. To override this behavior, set this optional input to true. 
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

    if nargin<3
        forceWrite = false;
    end

    % Does the path alraedy contain a recipe?
    tRecipes = dir(fullfile(dirName,'recipe_*_*.yml'));

    if isempty(tRecipes)
        recipeInPath = false;
    else tRecipes
        recipeInPath = true;
    end
    
    if recipeInPath && ~forceWrite
        writePath = [];
    else

        thisRecipe = obj.recipe2struct;

        recipeFname = sprintf('recipe_%s_%s.yml',obj.sample.ID,datestr(now,'yymmdd_HHMMSS'));

        %We call tile pattern to ensure that the recipe parameters are up to date. This may no longer be needed.
        obj.tilePattern; %TODO: ensure we no longer need this explicit call here. 

        writePath = fullfile(dirName,recipeFname);
        fprintf('Writing recipe to %s\n',writePath);
        BakingTray.yaml.WriteYaml(writePath,thisRecipe);

    end

    if nargout>0
        varargout{1}=writePath;
    end
