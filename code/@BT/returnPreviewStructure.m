function pStack = returnPreviewStructure(obj,chanToKeep)
    % return a "preview stack" that we can feed into the autoROI. 
    % Details on what the preview stack is are here:
    %  https://github.com/raacampbell/autofinder/issues/61
    % Not settled on a final spec yet. TODO!

    if nargin<2 || isempty(chanToKeep)
        chanToKeep=[];
    end

    % TODO -- this is ro90 for some reason
    im = squeeze(mean(obj.lastPreviewImageStack,3)); % Average depths

    % Get the channel with the highest median if no channel was requestes
    if isempty(chanToKeep)
        medc = squeeze([median(im,[1,2])]);
        [~,chanToKeep] = max(medc);
    end

    im = im(:,:,chanToKeep);

    % Build the output structure
    pStack.imStack = im;
    pStack.recipe = obj.recipe;
    pStack.voxelSizeInMicrons = obj.downsampleMicronsPerPixel;
    pStack.tileSizeInMicrons = 1E3 * obj.recipe.TileStepSize.X * (1/(1-pStack.recipe.mosaic.overlapProportion)); % ASSUMES SQUARE TILES
    pStack.nSamples = []; % TODO-- fill this in?
    pStack.fullFOV = true; % TODO - we need a smarter way of setting this. It should be false if the section was acquired with auto-ROI
end