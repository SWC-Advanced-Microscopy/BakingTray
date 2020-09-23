function out = findTissueAtROIedges(BW,BBstats,settings)
    % Expands ROIs that contain tissue at the edges
    %
    % function out = findTissueAtROIedges(BW,BBstats,settings)
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
    %
    %
    % Rob Campbell - SWC 2020


    if nargin<3
        settings = autoROI.readSettings;
    end

    makePlots = false;

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


function out = lookForTissueAtEdges(BW,ROI,settings)
    verbose=false;
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
    if out.NSEW(1)>eThresh && out.NSEW(2)>eThresh
        % Then it's both sides that are clipping. We grow accordingly
        ROI(2) = ROI(2) - growByPix;
        ROI(4) = ROI(4) + growByPix*2;

    elseif out.NSEW(1)>eThresh
        if verbose
            fprintf('\n\nEXPANDING\n\')
        end
        n = numClearPixels(flip(sampleProfileRows)); %if the clipped edge was on the north side we flip the word
        if n>growByPix
            ROI(2) = ROI(2)-n; %Shift up ROI by this much
        else
            %Increase height by the difference
            ROI(4) = ROI(4) + (growByPix-n);
            ROI(2) = ROI(2) - growByPix; %Now can shift up by e-thresh
        end
    elseif out.NSEW(2)>eThresh
        if verbose
            fprintf('\n\nEXPANDING\n\')
        end
        % South end clipped
        shiftROIUD=true;
        n = numClearPixels(sampleProfileRows);

        if n>growByPix
            ROI(2) = ROI(2)+n; %Shift down ROI by this much
        else
            %Increase height by the difference
            ROI(4) = ROI(4) + (growByPix-n);
            ROI(2) = ROI(2) + n; %Now can shift up by e-thresh
        end
    end



    % Repeat for LR
    if out.NSEW(3)>eThresh && out.NSEW(4)>eThresh
        % Then it's both sides that are clipping. We grow accordingly
        ROI(1) = ROI(1) - growByPix;
        ROI(3) = ROI(3) + growByPix*2;

    elseif out.NSEW(4)>eThresh
        % West clips
        n = numClearPixels(flip(sampleProfileCols)); %if the clipped edge was on the north side we flip the word
        if n>growByPix
            ROI(1) = ROI(1)-n; %Shift up ROI by this much
        else
            %Increase height by the difference
            ROI(3) = ROI(3) + (growByPix-n);
            ROI(1) = ROI(1) - growByPix; %Now can shift up by e-thresh
        end
    elseif out.NSEW(3)>eThresh
        % East clips
        shiftROIUD=true;
        n = numClearPixels(sampleProfileCols);

        if n>growByPix
            ROI(1) = ROI(1)+n; %Shift down ROI by this much
        else
            %Increase height by the difference
            ROI(3) = ROI(3) + (growByPix-n);
            ROI(1) = ROI(1) + n; %Now can shift up by e-thresh
        end
    end


    out.ROI = ROI;

function n = numClearPixels(sampleProfile)
    % Return the number of clear (empty) pixels between an edge and the sample
    % Sample profile must be flipped so that the first index corresponds to the edge we know has no sample

    n=0;
    sampleProfile = sampleProfile(:)'; % Get a row vector

    % Make a binary word to identify all locations with sample (zeros)
    bWord = strrep(num2str(sampleProfile==0),' ','');

    tok=regexp(bWord,'^(1+)','tokens'); %Search from the start
    if ~isempty(tok)
        n = length(tok{1}{1});
    end
