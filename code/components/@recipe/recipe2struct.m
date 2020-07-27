function recipeStruct=recipe2struct(obj)
    % Convert recipe to a structure
    % 
    % recipeStruct = recipe.writeFullRecipeForAcquisition
    %
    % Purpose
    % Turns all the public properties of the recipe class into a structure containing
    % their current values. Used by  recipe.writeFullRecipeForAcquisition amongst others.
    %
    % Also see:
    %  recipe.saveRecipe, recipe.writeFullRecipeForAcquisition

    theseFields = ['Acquisition';properties(obj)]; %Acquisition (which contains the acquisition start time) is hidden so is added explicitly here

    recipeStruct = struct;
    for ii=1:length(theseFields)

        % We have to manually add the NumTiles and TileStepSize fields because they're classes 
        % and WriteYaml can't handle this. 
        if isa(obj.(theseFields{ii}), theseFields{ii}) % sorry, I know it's naughty but can't help myself
            recipeStruct.(theseFields{ii}).X = obj.(theseFields{ii}).X;
            recipeStruct.(theseFields{ii}).Y = obj.(theseFields{ii}).Y;
            continue
        end

        recipeStruct.(theseFields{ii}) = obj.(theseFields{ii});
    end
