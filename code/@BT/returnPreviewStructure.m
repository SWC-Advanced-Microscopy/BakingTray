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

    % We need to choose which channel to keep and use for the autoROI. 
    % We ideally want the channel acquiring the longest wavelenth data. 
    % This is because agar autofluoresces a lot in blue at 2p excitation
    % wavelengths shorter than about 840 nm. To choose the right channel 
    % we need the channels named in ScanImage. If that is not the case, 
    % then we get the channel with the highest median. The channel order
    % by default is red,green,blue but it can be over-rideden by the user
    % in the system settings YAML file
    chanToKeep = getAutoROIChan(obj.scanner.getChannelNames,...
        obj.scanner.getChannelsToAcquire, ...
         obj.recipe.SYSTEM.autoROIchannelOrder);
    if isempty(chanToKeep)
        chanToKeep = determineChannelWithHighestSNR(im);
    end

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



% Non-nested internal functions follow
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

function chan = getAutoROIChan(chanNames,chansToAcquire,autoROIchannelOrder)
    % Use a cell array of channel names being acquired to figure out which
    % channel is the one we want for the autoROI. Based on setting found
    % in the recipe which comes from the system settings YAML.
    % Returns empty if the channel names are not informative enough for this.
    % Do not return the far red channel as this has very little
    % sample autofluorescence. 
    % This method expects channels to be named either: "Far Red", "Red", "Green", and "Blue"
    % OR: "Chan 1: Far Red", "Chan 2: Red", "Chan 3: Green", and "Chan 4: Blue"
    % Not all are needed but only those strings are expected. Case insensitive.
    %
    % Inputs
    % chanNames - the names of the channels that are available
    % chansToAcquire - vector indicating which indexes in chanNames are being e.g. [3,4]
    %
    % Outputs
    % chan - the channel in that list which is the lowest wavelength

    chan = [];
    chanNames = lower(chanNames);

    for ii=1:length(chanNames)
        % remove any leading text that looks like "chan 1: "
        chanNames{ii} = regexprep(chanNames{ii},'.*: ', '');
    end

    chanNamesAcq = chanNames(chansToAcquire);

    for ii=1:length(autoROIchannelOrder)
        tChan = autoROIchannelOrder{ii};
        ind = strmatch(tChan,chanNamesAcq);
        if ~isempty(ind)
            chan = chansToAcquire(ind);
            fprintf('Choosing channel %d (%s) for autoROI\n', chan, tChan)
            break
        end
    end

    if isempty(chan)
        fprintf('\nBT.returnPreviewStructre Failed to base channel to keep on wavelength\n')
    end

end


