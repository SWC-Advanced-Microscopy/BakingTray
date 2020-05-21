function attachPreviewStack(obj,pStack)
    % Attach a preview stack to the dummScanner so we can simulate acquisitions using past data
    %
    %  function attachPreviewStack(obj,pStack)
    %
    % Purpose
    % The dummyScanner class allow BakingTray to simulate acquisitions using past data. This
    % method attaches a "previewStack" structure to the dummyScanner. The previewStack is a
    % structure organised as follows:
    % pStack.imStack - 3D matrix. Each plane is an X/Y image from a stack. The third dimension
    %                  are depths. It's up to the user whether these are single physical sections
    %                  optical sections & physical sections mixed, etc. NOTE: By default, however,
    %                  this method sets its numOpticalPlanes property to 1 when this method is run.
    % pStack.voxelSizeInMicrons - the number of microns per pixel in pStack
    % pStack.recipe - The recipe structure with which the data were acquried.
    %
    %
    % Inputs
    % pStack - the preview structure (as defined above)
    %
    %
    % Outputs
    % None
    %
    %
    % Examples
    %  load some_pStack
    %  hBT.scanner.attachExistingData(pStack)



    verbose=true;

    % Add data to object, pulling out meta-data as needed
    obj.imageStackData=pStack.imStack;
    obj.imageStackVoxelSizeXY = pStack.voxelSizeInMicrons;
    obj.imageStackVoxelSizeZ = pStack.recipe.mosaic.sliceThickness;

    % Set the number of optical planes to 1 (TODO -- in future maybe we should be more flexible an not do this?)
    obj.numOpticalPlanes=1;
    obj.parent.recipe.mosaic.numOpticalPlanes=obj.numOpticalPlanes;
    obj.currentOpticalPlane=1;


    obj.getClim % Set the max plotted value


    % Initially move stage to origin to avoid any possible errors caused by it being out 
    % of position due to possibly larger previous sample
    obj.parent.moveXYto(0,0)


    % Pad sample by a couple of tiles preparation for autoROI. The pad value will be pi, 
    % so we can find it later and remove it from stats or whatever as needed. 
    % TODO -- maybe pi needs to be changed to something friendly to int16? See:
    %         https://github.com/SainsburyWellcomeCentre/BakingTray/issues/249
    padTiles=2;
    padBy =round(ceil(pStack.tileSizeInMicrons/pStack.voxelSizeInMicrons)*padTiles);

    obj.imageStackData = padarray(obj.imageStackData,[padBy,padBy,0],pi);

    % Report the new image size
    im_mmY = size(obj.imageStackData,2) * obj.imageStackVoxelSizeXY * 1E-3;
    im_mmX = size(obj.imageStackData,1) * obj.imageStackVoxelSizeXY * 1E-3;

    if verbose
        fprintf(['dummyScanner.%s -- Padding preview stack image by %d pixels (%0.1f tiles) ', ...
            'yielding a total area of x=%0.1f mm by y=%0.1f mm\n'], ...
            mfilename, padBy, padTiles, im_mmX, im_mmY)
    end

    % Set min/max limits of the stages so we can't scan outside of the available area
    obj.parent.xAxis.attachedStage.maxPos = 0;
    obj.parent.yAxis.attachedStage.maxPos = 0;

    obj.parent.xAxis.attachedStage.minPos = -floor(im_mmX) + pStack.tileSizeInMicrons*1E-3;
    obj.parent.yAxis.attachedStage.minPos = -floor(im_mmY) + pStack.tileSizeInMicrons*1E-3;
    if verbose
        fprintf('dummyScanner.%s Setting min allowed stage positions to: x=%0.2f y=%0.2f\n', ...
            mfilename, ...
            obj.parent.xAxis.attachedStage.minPos, ...
            obj.parent.yAxis.attachedStage.minPos)
    end

    % Move stages to the middle of the sample area so we are more likely to see something if we take an image
    midY = -im_mmY/2;
    midX = -im_mmX/2;
    obj.parent.moveXYto(midX,midY)



    % Determine reasonable x and y limits for the section image so we don't display the padded area
    % in the dummyScanner GUI
    obj.sectionImage_xlim = [padBy+1,size(obj.imageStackData,2)-padBy-1];
    obj.sectionImage_ylim = [padBy+1,size(obj.imageStackData,1)-padBy-1];

    % Set scanner pixel size to match that of the pStack
    obj.scannerSettings.micronsPerPixel_cols = pStack.voxelSizeInMicrons;
    obj.scannerSettings.micronsPerPixel_rows = pStack.voxelSizeInMicrons;

    % Set the sample size to something reasonable based on the area of the sample
    obj.scannerSettings.FOV_alongColsinMicrons = pStack.tileSizeInMicrons;
    obj.scannerSettings.FOV_alongRowsinMicrons = pStack.tileSizeInMicrons;

    obj.scannerSettings.pixelsPerLine = round(obj.scannerSettings.FOV_alongColsinMicrons / obj.imageStackVoxelSizeXY);
    obj.scannerSettings.linesPerFrame = round(obj.scannerSettings.FOV_alongColsinMicrons / obj.imageStackVoxelSizeXY);

    % Calculate the extent of the originally imaged area
    obj.parent.recipe.mosaic.sampleSize.Y = size(pStack.imStack,2) * obj.imageStackVoxelSizeXY*1E-3;
    obj.parent.recipe.mosaic.sampleSize.X = size(pStack.imStack,1) * obj.imageStackVoxelSizeXY*1E-3 ;


    % Set the front/left (plus a pixel) so we start at the corner of the sample, not the padded area
    obj.parent.recipe.FrontLeft.X = -(padBy+1) * pStack.voxelSizeInMicrons * 1E-3;
    obj.parent.recipe.FrontLeft.Y = -(padBy+1) * pStack.voxelSizeInMicrons * 1E-3;

    if verbose
        fprintf('Front/Left is at %0.2f x %0.2f mm\n', ...
            obj.parent.recipe.FrontLeft.X, ...
            obj.parent.recipe.FrontLeft.Y)
    end



    % Update recipe values to reflect the preview stack we have imported

    % Set the stitching voxel size in the recipe
    obj.parent.recipe.StitchingParameters.VoxelSize.X = pStack.voxelSizeInMicrons;
    obj.parent.recipe.StitchingParameters.VoxelSize.Y = pStack.voxelSizeInMicrons;

    % Set the number of sections in the recipe file based on the number available in the stack
    obj.parent.recipe.mosaic.numSections=size(pStack.imStack,3);

    obj.parent.recipe.sample.ID = pStack.recipe.sample.ID;
    obj.parent.recipe.mosaic.overlapProportion = pStack.recipe.mosaic.overlapProportion;


    % Reset counters in BakingTray
    obj.parent.currentSectionNumber=1;
    obj.parent.currentTilePosition=1;

end
