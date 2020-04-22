function attachPreviewStack(obj,pStack)
    %  function attachPreviewStack(obj,pStack)
    %
    %  e.g.
    %  load some_pStack
    %  hBT.scanner.attachExistingData(pStack)



    % Add data to object
    obj.imageStackData=pStack.imStack;
    obj.imageStackVoxelSizeXY = pStack.voxelSizeInMicrons;
    obj.imageStackVoxelSizeZ = pStack.recipe.mosaic.sliceThickness;

    % Set the number of optical planes to 1, as we won' be doing this here
    obj.numOpticalPlanes=1;
    obj.parent.recipe.mosaic.numOpticalPlanes=obj.numOpticalPlanes;
    obj.currentOpticalPlane=1;

    obj.getClim % Set the max plotted value

    % Initially move stage to origin to avoid any possible errors caused by it being out 
    % of position due to possibly larger previous sample
    obj.parent.moveXYto(0,0)

    % pad sample by about a tile preparation for autoROI. The pad value will be pi, 
    % so we can find it later and remove it from stats or whatever as needed. 
    padBy = round(ceil(pStack.tileSizeInMicrons/pStack.voxelSizeInMicrons)*1.25);
    obj.imageStackData = padarray(obj.imageStackData,[padBy,padBy,0],pi);


    % Move stages to the middle of the sample area so we are more likely to see something if we take an image
    im_mmY = size(obj.imageStackData,2) * obj.imageStackVoxelSizeXY * 1E-3;
    im_mmX = size(obj.imageStackData,1) * obj.imageStackVoxelSizeXY * 1E-3;

    % Set min/max limits of the stages so we can't scan outside of the available area
    obj.parent.xAxis.attachedStage.maxPos = 0;
    obj.parent.yAxis.attachedStage.maxPos = 0;

    obj.parent.xAxis.attachedStage.minPos = -floor(im_mmX) - pStack.tileSizeInMicrons*1E-3;
    obj.parent.yAxis.attachedStage.minPos = -floor(im_mmY) - pStack.tileSizeInMicrons*1E-3;

    % Move to the middle of the FOV
    midY = -im_mmY/2;
    midX = -im_mmX/2;
    obj.parent.moveXYto(midX,midY)

    % Set the sample size to something reasonable based on the area of the sample
    obj.scannerSettings.FOV_alongColsinMicrons=pStack.tileSizeInMicrons;
    obj.scannerSettings.FOV_alongRowsinMicrons=pStack.tileSizeInMicrons;


    obj.scannerSettings.pixelsPerLine=round(obj.scannerSettings.FOV_alongColsinMicrons / obj.imageStackVoxelSizeXY);
    obj.scannerSettings.linesPerFrame=round(obj.scannerSettings.FOV_alongColsinMicrons / obj.imageStackVoxelSizeXY);

    tilesY = floor(size(obj.imageStackData,2) / obj.scannerSettings.pixelsPerLine);
    tilesX = floor(size(obj.imageStackData,1) / obj.scannerSettings.pixelsPerLine);
    obj.parent.recipe.mosaic.sampleSize.Y=floor(tilesY);
    obj.parent.recipe.mosaic.sampleSize.X=floor(tilesX);

    % Set the front/left so we start at the corner of the sample, not the padded area
    obj.parent.recipe.FrontLeft.X = -padBy * pStack.voxelSizeInMicrons * 1E-3;
    obj.parent.recipe.FrontLeft.Y = -padBy * pStack.voxelSizeInMicrons * 1E-3;

    % Set the number of sections in the recipe file based on the number available in the stack
    obj.parent.recipe.mosaic.numSections=size(pStack.imStack,3);
    hBT.currentTilePosition=1;

    % Determine reasonable x and y limits for the section image so we don't display
    % the padded area
    obj.sectionImage_xlim = [padBy+1,size(obj.imageStackData,2)-padBy-1];
    obj.sectionImage_ylim = [padBy+1,size(obj.imageStackData,1)-padBy-1];

end