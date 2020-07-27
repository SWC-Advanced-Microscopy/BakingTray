function pStack = replaceRecipe(pStack,pathToRecipe)
% Replace the recipe and re-calculate the number of microns per pixel
%
% autoROI.groundTruth.replaceRecipe(pStack,pathToRecipe)
%
% Purpose
% To correct cases where the wrong recipe file was used.
%
%
% Inputs
% pStack - Existing pStack structure
% pathToRecipe - Path to this sample's recipe file. If empty, the function
%               just re-processes using the existing recipe.



if ~isempty(pathToRecipe) && ischar(pathToRecipe) && exist(pathToRecipe,'file')
    % Get the downsampled tile size
    recipe=yaml.ReadYaml(pathToRecipe);
elseif isempty(pathToRecipe) && isfield(pStack,'recipe')
    recipe=pStack.recipe
else
    fprintf('NO RECIPE\n')
    return
end


tileSize = recipe.VoxelSize.X * recipe.Tile.nRows; %assume square tiles

% TODO (BAD) the following will work on SWC rigs for sure but maybe not elsewhere. 
% If X/Y are flipped for some reason. 
% TODO - it also may not be valid once we start to use the auto finder
imageExtentInY = recipe.NumTiles.Y * tileSize * (1-recipe.mosaic.overlapProportion);
voxelSize = imageExtentInY / size(pStack.imStack,2);



% Report and replace
fprintf('Recipe sample name: %s -> ', pStack.recipe.sample.ID);
pStack.recipe = recipe;
fprintf('%s\n', pStack.recipe.sample.ID);


fprintf('Voxel size: %0.3f -> ', pStack.voxelSizeInMicrons);
pStack.voxelSizeInMicrons = voxelSize;
fprintf('%0.3f\n', pStack.voxelSizeInMicrons);


fprintf('Tile size: %0.1f -> ', pStack.tileSizeInMicrons);
pStack.tileSizeInMicrons = tileSize;
fprintf('%0.1f\n', pStack.tileSizeInMicrons);




