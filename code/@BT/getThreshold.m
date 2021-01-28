function success=getThreshold(obj)
    % Get threshold from current preveiw image
    %
    % success = BT.getThreshold
    %
    % Purpose
    % Runs autoROI.autoThresh to get a threshold based on obj.autoROI.previewImages
    % Once done, populates  BT.autoROI.stats with the output of autoROI. This wipes
    % whatever was there before. This method is run once by the user when they are 
    % about to start the acquisition. See also BT.getNextROIs, which runs at the end
    % of each section. The thresholds are calculated within autoROI.m once the
    % acquisition has started. 
    %
    %
    % Rob Campbell - SWC, April 2020


    success=false;
    if isempty(obj.lastPreviewImageStack)
        return
    end

    % First wipe the structure to completely ensure we don't end up with one 
    % that is a chimera of different preview stacks or threshold runs.
    obj.autoROI =[];
    obj.autoROI.previewImages=obj.returnPreviewStructure;

    % Do not proceed if the image seems empty
    if all( obj.autoROI.previewImages.imStack(:) == mode(obj.autoROI.previewImages.imStack(:)) )
        fprintf('BT.%s finds an empty preview image. Not running threshold algorithm\n', ...
            mfilename)
        return
    end

    % Obtain the threshold -- TODO the GMM alg returns a tThresh not a tThreshSD
    threshSD = autoROI.autoThresh(obj.autoROI.previewImages.imStack);

    % Bail out if it failed
    if isnan(threshSD)
        obj.messageString = 'Auto-Thresh failed to find the sample';
        return
    end

    % Get stats
    obj.autoROI.stats=autoROI(obj.autoROI.previewImages,[],'tThreshSD',threshSD,'doPlot',false);
    obj.autoROI.stats.roiStats.sectionNumber=0; %Indicates that this is the initial preview

    % Log which channels the user has chosen to acquire
    obj.autoROI.stats.channelsToSave = obj.scanner.getChannelsToAcquire;

    % Log the brightest channel index to the stats structure
    obj.autoROI.channel = obj.autoROI.previewImages.channel;

    % Set for display only the brightest channel
    obj.scanner.setChannelsToDisplay(obj.autoROI.channel);

    success=true;
end % getThreshold
