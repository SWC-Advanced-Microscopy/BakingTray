function out = findTissueAtROIedges(BW,BBstats,settings)
    % Does the edge of a ROI contain tissue?
    %
    % function out = findTissueAtROIedges(BW,BBstats)
    %
    %


    if nargin<3
        settings = autoROI.readSettings;
    end


    % convert to cell array if needed
    if isstruct(BBstats)
        BBstats = {BWstats.BoundingBox};
    end


    imagesc(BW)
    cellfun(@(x) autoROI.overlayBoundingBox(x),BBstats)

    for ii=1:length(BBstats)
        tBW=autoROI.getSubImageUsingBoundingBox(BW,BBstats{ii});
        edgeData = lookForTissueAtEdges(tBW,BBstats{ii},settings);
        BBstats{ii} = edgeData.ROI;
    end

    disp('PRESS RETURN'), pause
    imagesc(BW)
    cellfun(@(x) autoROI.overlayBoundingBox(x),BBstats)




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
    if any(out.NSEW(1:2)>eThresh)
        
        %plot(sampleProfileRows==0,'ok-')
        if out.NSEW(1)>eThresh && out.NSEW(2)>eThresh
            % Then it's both sides that are clipping. We grow accordingly

        elseif out.NSEW(1)>eThresh
            n = numClearPixels(flip(sampleProfileRows)); %if the clipped edge was on the north side we flip the word


            if n>eThresh
                ROI(2) = ROI(2)-n; %Shift up ROI by this much
            else
                %Increase height by the difference
                ROI(4) = ROI(4) + (eThresh-n);
                ROI(4) = ROI(4) + eThresh; %Now can shift up by e-thresh

            end
        elseif out.NSEW(2)>eThresh
            shiftROIUD=true;
            n = numClearPixels(sampleProfileRows);
        end

        % Repeat for LR

        %Expand ROI, say, 750 microns in the direction of the clipping. We can subtract the above. 
        %We need to know the scale factor. 
        %Then we feed back to ROIs from calller function.

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
