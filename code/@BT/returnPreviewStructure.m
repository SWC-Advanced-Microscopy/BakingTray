function pStack = returnPreviewStructure(obj,chanToKeep)
    % return a "preview stack" that we can feed into the autoROI.
    % Details on what the preview stack is are here:
    %  https://github.com/raacampbell/autofinder/issues/61
    % Not settled on a final spec yet. TODO!

    if nargin<2 || isempty(chanToKeep)
        chanToKeep=[];
    end

    verbose = true;

    % TODO -- this is ro90 for some reason
    im = squeeze(mean(obj.lastPreviewImageStack,3)); % Average depths


    % Get the channel with the highest median if no channel was requested
    if isempty(chanToKeep)
        chanToKeep = determineChannelWithHighestSNR(im);
    end

    im = im(:,:,chanToKeep);

    % Build the output structure
    pStack.imStack = int16(im); % The auto-thresh can fail unless this an int16
    pStack.recipe = obj.recipe;
    pStack.voxelSizeInMicrons = obj.downsampleMicronsPerPixel;
    pStack.tileSizeInMicrons = 1E3 * obj.recipe.TileStepSize.X * (1/(1-pStack.recipe.mosaic.overlapProportion)); % ASSUMES SQUARE TILES


    % Log the front/left stage position when this preview image was obtained. This information is 
    % recorded by the method BT.initialisePreviewImageData, which stores it in BT.frontLeftWhenPreviewWasTaken
    % For stacks where we are not using autoROI, this front/left position will be the same for all sections. 
    % For autoROI stacks it will vary by section. 
    pStack.frontLeftStageMM = obj.frontLeftWhenPreviewWasTaken;

    pStack.nSamples = []; % TODO-- fill this in?

    pStack.fullFOV = true; % TODO - we need a smarter way of setting this. It should be false if the section was acquired with auto-ROI


    if verbose
        fprintf('BT.%s makes pStack with image of size %d by %d and frontLeftStageMM x=%0.2f y=%0.2f\n', ...
            mfilename, size(im), pStack.frontLeftStageMM.X, pStack.frontLeftStageMM.Y)
    end
end


function chan = determineChannelWithHighestSNR(im)
    % Determine the plane with the largest range, which we treat as being that with the highest SNR. 
    chanRange = zeros(1,size(im,3));
    for ii = 1:size(im,3)
        tChan = im(:,:,ii);
        tChan(tChan == -42) = nan;
        tChan(tChan == -123) = nan;

        tChan = medfilt2(tChan,[3,3]);
        tChan = tChan(:);

        % remove pixels that did not have data laid down

        chanRange(ii) = range(tChan);
        %fprintf('Channel %d: range %d\n', ii, chanRange(ii))
    end

    [~,chan] = max(chanRange);

end
