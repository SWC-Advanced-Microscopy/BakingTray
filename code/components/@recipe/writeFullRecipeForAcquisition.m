function writeFullRecipeForAcquisition(obj)
    % Write recipe to disk and name it according to the sample ID and today's date
    % 
    % recipe.writeFullRecipeForAcquisition
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
    % Also see:
    %  recipe.saveRecipe 


    theseFields = ['Acquisition';properties(obj)]; %Acquisition (which contains the acquisition start time) is hidden so is added explicitly here

    thisRecipe = struct;
    for ii=1:length(theseFields)
        thisRecipe.(theseFields{ii}) = obj.(theseFields{ii});
    end


    recipeFname = sprintf('recipe_%s_%s.yml',obj.sample.ID,datestr(now,'yymmdd'));

    %We call tile pattern to ensure that the recipe parameters are up to date. This may no longer be needed.
    obj.tilePattern; %TODO: ensure we no longer need this explicit call here. 

    BakingTray.yaml.WriteYaml(recipeFname,thisRecipe);

