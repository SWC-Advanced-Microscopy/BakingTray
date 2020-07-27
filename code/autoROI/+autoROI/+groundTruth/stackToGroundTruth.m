function pStack = stackToGroundTruth(imStack,pathToRecipe,nSamples)
% Wrap an image stack into a "ground truth" structure (pStack) for testing
%
% autoROI.groundTruth.stackToGroundTruth(imStack,pathToRecipe,nSamples)
%
% Purpose
% The "groundTruth" structure will be used for testing the behavior of the ROI-finding
% algorithm. This function produces the structure. The structure should contain all the 
% parameters we need to obtain a ground truth sample border against which we can go on to 
% test whether or not the auto-ROI-finder has managed to identify the whole sample. 
%
%
% Inputs
% imStack - The preview image stack produced by previewFilesToTiffStack from BakingTray.
% pathToRecipe - Path to this sample's recipe file
% nSamples - the number of samples (e.g. brains) contained in imStack. Some acquisitions 
%            have multiple samples. 
%
%
%


if nargin<3 || isempty(nSamples)
    nSamples=1;
end


% Get the downsampled tile size
recipe=yaml.ReadYaml(pathToRecipe);

tileSize = recipe.VoxelSize.X * recipe.Tile.nRows; %assume square tiles

% TODO (BAD) the following will work on SWC rigs for sure but maybe not elsewhere. 
% If X/Y are flipped for some reason. 
% TODO - it also may not be valid once we start to use the auto finder
imageExtentInY = recipe.NumTiles.Y * tileSize * (1-recipe.mosaic.overlapProportion);
voxelSize = imageExtentInY / size(imStack,2);



pStack.imStack = imStack;
pStack.recipe = recipe;
pStack.voxelSizeInMicrons = voxelSize;
pStack.tileSizeInMicrons = tileSize;
pStack.nSamples = nSamples;
pStack.binarized = [];
pStack.borders = {};
