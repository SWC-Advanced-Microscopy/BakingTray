function thresh = getThreshFromROIstats(stats)
% Get threshold value from ROI stats
%
% function thresh = autoROI.getThreshFromROIstats(stats)
%
% Purpose
% Extract tThresh value from the last section, median of the last few
% or just use the first section. All according to what the settings
% are
%
% This function is used by autoROI.runOnStackStruct and BT.getNextROIs


    settings = autoROI.readSettings;
    rollingThreshold=settings.stackStr.rollingThreshold; %If true we base the threshold on the last few slices
    nImages = settings.stackStr.nImages;


    % Use a rolling threshold based on the last nImages to drive sample/background
    % segmentation in the next image. If set to zero it uses the preceeding section.

    if rollingThreshold==false
        % Do not update the threshold at all: use only the values derived from the first section
        thresh = stats.roiStats(1).tThresh;
    elseif nImages==0
        % Use the threshold from the last section: TODO shouldn't this be (ii) not (ii-1)?
        thresh = stats.roiStats(end).tThresh;
    elseif length(stats.roiStats)<=nImages
        % Attempt to take the median value from the last nImages: take as many as possible 
        % until we have nImages worth of sections 
        thresh = median([stats.roiStats.tThresh]);
    else
        % Take the median value from the last nImages 
        thresh = median([stats.roiStats(end-nImages+1:end).tThresh]);
    end
