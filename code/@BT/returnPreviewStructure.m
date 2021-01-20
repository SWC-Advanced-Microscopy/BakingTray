function pStack = returnPreviewStructure(obj)
    % return a "preview stack" that we can feed into the autoROI.
    %
    % Purpose
    % The preview stack (pStack) is a structure that contains an average of 
    % all depths in the last preview image. If the preview image contains
    % multiple channels, this method finds the one with the greatest range
    % and returns only that.
    %
    % Details on what the preview stack is are here:
    %  https://github.com/raacampbell/autofinder/issues/61



    verbose = true;

    im = squeeze(mean(obj.lastPreviewImageStack,3)); % Average depths

    % Get the channel with the highest median if no channel was requested
    chanToKeep = determineChannelWithHighestSNR(im);

    im = im(:,:,chanToKeep);

    % Build the output structure
    pStack.imStack = int16(im); % The auto-thresh can fail unless this an int16
    pStack.recipe = obj.recipe.recipe2struct; % store recipe as a structure to easy loading
    pStack.voxelSizeInMicrons = obj.downsampleMicronsPerPixel;
    pStack.tileSizeInMicrons = 1E3 * obj.recipe.TileStepSize.X * (1/(1-pStack.recipe.mosaic.overlapProportion)); % ASSUMES SQUARE TILES
    pStack.channel = chanToKeep;
    pStack.tileOverlapProportion = obj.recipe.mosaic.overlapProportion;
    % Now only acquire this channel for the preview
    if isa(obj.scanner,'SIBT')
        % A bit horrible, but it will work
        fprintf('Preview image will display only channel %d from now on\n', chanToKeep);
        obj.scanner.hC.hChannels.channelDisplay=chanToKeep;
    end
      

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



% Non-nested internal functions folloe
function chan = determineChannelWithHighestSNR(im)
    % Determine the plane with the largest range, which we treat as being that with the highest SNR. 
    %
    % Purpose
    % Used by auto-ROI to choose which channel to base the acquisition on. 
    %
    % Inputs
    % im - the preview image
    %
    % Outputs
    % chan - the channel which is brightest

    chanRange = zeros(1,size(im,3));
    for ii = 1:size(im,3)
        tChan = im(:,:,ii);

        % Remove things that may be non-imaged pixels
        tChan(tChan == -42) = nan;  %Test data are padded with -42
        tChan(tChan == 0) = nan;

        tChan = medfilt2(tChan,[3,3]);
        tChan(tChan == 0) = nan; % Remove the padding values

        tChan = tChan(:);
        chanRange(ii) = range(tChan);
        %fprintf('Channel %d: min: %d; max: %d; range %d\n', ii, ...
        %    min(tChan), max(tChan), chanRange(ii))
    end

    [~,chan] = max(chanRange);

end
