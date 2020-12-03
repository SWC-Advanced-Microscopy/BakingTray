function [out,roiChanged,edgeData] = findTissueAtROIedges(BW,BBstats,settings,makePlots)
    % Expands ROIs that contain tissue at the edges
    %
    % function [out,roiChanged] = findTissueAtROIedges(BW,BBstats,settings)
    %
    %
    % Purpose
    % Expand ROIs that contain tissue at the edges. This function is intended to 
    % be called from other functions rather than directly by the user.
    %
    %
    % Inputs [required]
    % BW - the binarized images where 1s are areas with tissue and 0s are areas without
    % BBstats - the first output argument of regionprops (or a cell array of boundingboxes)
    % 
    % Inputs [optional]
    % settings - the outpit of autoROI.readSettings
    %
    % Outputs
    % out - the modified version of stats, with larger bounding boxes
    % roiChanged - true if ROI has been modified
    %
    %
    % Rob Campbell - SWC 2020


    if nargin<3 || isempty(settings)
        settings = autoROI.readSettings;
    end

    if nargin<4
        makePlots = false;
    end

    % convert to cell array if needed
    out = BBstats; 
    if isstruct(BBstats)
        BBstats = {BBstats.BoundingBox};
    end


    if makePlots
        imagesc(BW)
        cellfun(@(x) autoROI.overlayBoundingBox(x),BBstats)
        drawnow, pause(1.15)
    end

    for ii=1:length(BBstats)
        tBW=autoROI.getSubImageUsingBoundingBox(BW,BBstats{ii});
        edgeData = lookForTissueAtEdges(tBW,BBstats{ii},settings);
        BBstats{ii} = edgeData.ROI;
    end


    if makePlots
        imagesc(BW)
        disp(edgeData)
        cellfun(@(x) autoROI.overlayBoundingBox(x),BBstats)
    end

    % Return the output in the same format as the input
    if iscell(out)
        out = BBstats;
    elseif isstruct(out)
        for ii = 1:length(out)
            out(ii).BoundingBox = BBstats{ii};
        end
    end


    if any(edgeData.NSEW)
        roiChanged = true;
    else
        roiChanged = false;
    end


function out = lookForTissueAtEdges(BW,ROI,settings)
    % this function is called by getBoundingBoxes, which works with downsampled images defined thus:
    micsPix = settings.main.rescaleTo; 

    eThresh = settings.clipper.edgeThreshMicrons / micsPix;
    growByPix = settings.clipper.growROIbyMicrons / micsPix;

    out.NSEW = [sum(BW(1,:)), ...
                sum(BW(end,:)), ...
                sum(BW(:,end)), ...
                sum(BW(:,1))];
    out.ROI = ROI;
    if ~any(out.NSEW)
        return
    end

    % These will be used to detect clipping
    sampleProfileRows = sum(BW,2);
    sampleProfileCols = sum(BW,1);

    % This deals with cases where there is tissue at the edges on the North and/or South sides
    %plot(sampleProfileRows==0,'ok-')

    if out.NSEW(1)>eThresh
        % North end clipped
        ROI(4) = ROI(4) + growByPix;
        ROI(2) = ROI(2) - growByPix;
    end

    if out.NSEW(2)>eThresh
        % South end clipped
        ROI(4) = ROI(4) + growByPix;
    end



    % Repeat for LR
    if out.NSEW(4)>eThresh
        % West clips
        ROI(3) = ROI(3) + growByPix;
        ROI(1) = ROI(1) - growByPix;
    end

    if out.NSEW(3)>eThresh
        % East clips
        ROI(3) = ROI(3) + growByPix;
    end


    out.ROI = ROI;
