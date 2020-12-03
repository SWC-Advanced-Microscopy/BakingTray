function fixMixPix
    % Correct the number of microns per pixel
    %
    % Purpose
    % This function can be used to correct the number of microns per pixel in preview stacks
    % It's a bit of a hacky/throwaway function but we keep it for now. 


runDir='stacks';
pStack_list = dir(fullfile(runDir, '/**/*_previewStack.mat'));

if isempty(pStack_list)
    fprintf('Found no preview stacks in %s\n',runDir)
    return
end




for ii=1:length(pStack_list)
    tFile = fullfile(pStack_list(ii).folder,pStack_list(ii).name);
    fprintf('Loading %s\n',tFile)
    load(tFile)
    
    % Get some variables
    if ~isfield(pStack,'recipe')
        fprintf(' ---> NO RECIPE IN THIS SAMPLE!\n\n')
        continue
    end
    r=pStack.recipe;

    tilesLength =  max([r.NumTiles.X,r.NumTiles.Y]);
    voxSize = r.VoxelSize.X;
    ovLap = r.mosaic.overlapProportion;
    tileSizePix = r.Tile.nRows;

    % Calculate the voxel size
    tileSizeMics = tileSizePix*voxSize;
    lengthAcquisitionMics = tileSizeMics * tilesLength * (1-ovLap);

    dsPixLength = max(size(pStack.imStack,1:2));

    
    % Replace
    fprintf('Voxel size was %0.3f. Now %0.3f\n', ...
        pStack.voxelSizeInMicrons, lengthAcquisitionMics/dsPixLength)
    pStack.voxelSizeInMicrons = lengthAcquisitionMics/dsPixLength;

    fprintf('Tile size was %d. Now %d\n', ...
        round(pStack.tileSizeInMicrons), round(tileSizeMics))
    pStack.tileSizeInMicrons = tileSizeMics;

    fprintf('Saving\n\n')
    save('-v7.3',tFile,'pStack')

end