function getNextROIs(obj)
    % Get the ROIs in the currently imaged section in order to apply to the next
    % EARLY TEST
    % TODO -- tidy and doc it
    %
    % Rob Campbell - SWC, April 2020
    %

    if isempty(obj.lastPreviewImageStack)
        return
    end

    pStack = obj.autoROI.previewImages;
    pStack.fullFOV=false;
    obj.autoROI.previewImages=obj.returnPreviewStructure;


    settings = autoROI.readSettings;

    % TODO -- maybe these tests should be in a separate method?
    if isempty(obj.autoROI)
        fprintf('\nBT.autoROI is empty! Can not find next ROIs\n')
    elseif isempty(obj.autoROI.stats)
        fprintf('\nBT.autoROI.stats is empty! Can not find next ROIs\n')
    end

    stats = obj.autoROI.stats;



    % Use a rolling threshold based on the last nImages to drive sample/background
    % segmentation in the next image. If set to zero it uses the preceeding section.
    nImages=5;
    if length(stats.roiStats) <= nImages
        % Attempt to take the median value from the last nImages: take as many as possible 
        % until we have nImages worth of sections 
        thresh = median( [stats.roiStats.medianBackground] + [stats.roiStats.stdBackground]*stats.roiStats(end).tThreshSD);
    else
        % Take the median value from the last nImages 
        thresh = median( [stats.roiStats(end-nImages+1:end).medianBackground] + [stats.roiStats(end-nImages+1:end).stdBackground]*stats.roiStats(end).tThreshSD);
    end


    obj.autoROI.stats = autoROI(pStack, ...
        'doPlot', false, ...
        'settings', settings, ...
        'tThreshSD',stats.roiStats(end).tThreshSD, ...
        'tThresh',thresh,...
        'lastSectionStats',stats);


end % getThreshold