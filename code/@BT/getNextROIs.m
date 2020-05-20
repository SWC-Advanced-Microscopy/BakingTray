function getNextROIs(obj)
    % Determine which ROIs to image in the subsequent physical section.
    %
    % function BT.getNextROIs(obj)
    %
    % Purpose
    % This method sets the bounding boxes for the *next* physical section. To achieve this
    % it first runs BT.returnPreviewStructure, which provides a structure containing the 
    % current preview image plus other relevant information. This is fed into a function
    % called "autoROI". Also fed into this function is a "stats" structure that contains 
    % information on where the ROIs are. This is somewhat confusing and works as follows:
    %
    % 1) User runs a preview scan, where the whole FOV is imaged. From this ROIs are selected. 
    %    These ROIs are stored in BT.autoROI.stats.roiStats, as described above. At this
    %    point BT.autoROI.stats.roiStats has a length of 1. 
    % 2) We enter BT.bake and image section 1 using the ROIs from the preview.
    % 3) After we have imaged the ROIs this method is run. It pulls in the ROI image using
    %    the method BT.returnPreviewStructure
    % 4) autoROI is run using this image and the ROIs used to image section 1. This mean that 
    %    the autoROI function must chop up the large preview image into the defined ROIs and
    %    analyse each in turn to decide what will happen to this imaged area (smaller, bigger,
    %    translate it).
    % 5) autoROI returns an output such that BT.autoROI.stats.roiStats now has a length of 2.
    %    The second (final) element contains the ROIs for section 2. We image section 2 then 
    %    go back to step 3, above. We keep looping until all brain is imaged or max number of
    %    sections reached. 
    %
    % There is one non-obvious detail that is important. Consider these two points:
    % i) The ROIs calculated from section n are not used image section n, but section n+1.
    %    In other words, the ROIs in BT.autoROI.stats.roiStats(n) were *calculated* using 
    %    section n-1. 
    % ii) The stage front/left position of the section image will almost certainly change
    %     from section to section. 
    % BUT we feed into autoROI the current section image, n, and the ROIs used to image it.
    % However, those ROIs were obtained from image n-1. Thus, the current section image
    % and the ROIs in index n do not share the same front/left position and so we can't 
    % just feed them into autoROI. 
    %
    % Thus, after we have extracted the pStack from section n (step 3, above) we also must 
    % shift the ROIs in BT.autoROI.stats.roiStats(n), as these were extracted from section
    % n-1. Once we have done this, the image extract from section n and the ROIs at index
    % in BT.autoROI.stats.roiStats(n) will overlay each other **even though the ROIs were
    % extracted from section n-1. 
    %
    %
    % Rob Campbell - SWC, April 2020
    %
    % Also See:
    % This function does some of what happens in autoROI.test.runOnStackStruct 

    verbose=true;


    if isempty(obj.lastPreviewImageStack)
        return
    end

    if verbose
        fprintf('%s is getting previewImages\n',mfilename)
    end
    obj.autoROI.previewImages = obj.returnPreviewStructure;
    pStack = obj.autoROI.previewImages;
    pStack.sectionNumber = obj.currentSectionNumber+1;
    pStack.fullFOV=false;


    settings = autoROI.readSettings;

    % TODO -- maybe these tests should be in a separate method?
    if isempty(obj.autoROI)
        fprintf('\nBT.autoROI is empty! Can not find next ROIs\n')
    elseif isempty(obj.autoROI.stats)
        fprintf('\nBT.autoROI.stats is empty! Can not find next ROIs\n')
    end

    stats = obj.autoROI.stats;


    % Use a rolling threshold based on the last nImages to drive sample/background
    % segmentation in the next image. If set to zero it uses the preceding section.
    nImages=5;
    if length(stats.roiStats) <= nImages
        % Attempt to take the median value from the last nImages: take as many as possible 
        % until we have nImages worth of sections 
        thresh = median( [stats.roiStats.medianBackground] + [stats.roiStats.stdBackground]*stats.roiStats(end).tThreshSD);
    else
        % Take the median value from the last nImages 
        thresh = median( [stats.roiStats(end-nImages+1:end).medianBackground] + [stats.roiStats(end-nImages+1:end).stdBackground]*stats.roiStats(end).tThreshSD);
    end


    if verbose
        fprintf('%s is running autoROI\n',mfilename)
    end


    % We need to ensure that autoROI uses as ROIs the areas we last imaged.
    % The "correct" way to this is to use the ROIs with which the section was imaged
    % and shift them.
    obj.autoROI.stats.roiStats(end) = autoROI.shiftROIsBasedOnStageFrontLeft(pStack.frontLeftStageMM,stats.roiStats(end));

    % TODO -- Is is correct the way we feed in stats.roiStats(end).tThreshSD? 
    %         We need to handle cases where the threshold is re-run as well. 
    doPlot=false; % If true we plot the output of autoROI and pause after the plot. This is for
                  % debugging purposes only. 
    if doPlot
        figure(999)
    end
    obj.autoROI.stats = autoROI(pStack, ...
        'doPlot', doPlot, ...
        'settings', settings, ...
        'tThreshSD',stats.roiStats(end).tThreshSD, ...
        'tThresh',thresh,...
        'lastSectionStats',stats);
    
    if doPlot
        drawnow
        disp(' ** PRESS RETURN **')
        pause
    end

    % Add the section number to the  ROI stats
    obj.autoROI.stats.roiStats(end).sectionNumber=obj.currentSectionNumber;



    % Update the current tile pattern so that we will image these ROIs
    %  - currentTilePatern (where the stage will go)
    %  - positionArray (where the tiles will go in the preview image matrix)
    obj.populateCurrentTilePattern

end % getThreshold

