function out = findTissueAtROIedges(BW,BBstats)
    % Does the edge of a ROI contain tissue?
    %
    % function out = findTissueAtROIedges(BW,BBstats)
    %
    %

    settings = autoROI.readSettings;

    % convert to cell array if needed
    if isstruct(BBstats)
        BBstats = {BWstats.BoundingBox};
    end


    imagesc(BW)
    cellfun(@(x) autoROI.overlayBoundingBox(x),BBstats)

    for ii=1:length(BBstats)
        tBW=autoROI.getSubImageUsingBoundingBox(BW,BBstats{ii});
        edgeData(ii) = lookForTissueAtEdges(tBW);
    end




function out = lookForTissueAtEdges(BW)


    out.NSEW = [sum(BW(1,:)), ...
                sum(BW(end,:)), ...
                sum(BW(:,end)), ...
                sum(BW(:,1))];

    if ~any(out.NSEW)
        return
    end

    % First let's see if the box can be moved

    sampleProfileRows = sum(BW,2)';
    sampleProfileCols = sum(BW,1);

    % This deals with cases where there is tissue at the edges on the North and/or South sides
    if any(out.NSEW(1:2))
        % Make a binary word to identify all the zeros
        bWord = strrep(num2str(sampleProfileRows==0),' ','');

        if out.NSEW(1) && out.NSEW(2)
            % Then it's both sides that are clipping.
            shiftROIUD=false;
        elseif out.NSEW(1)
            %if the edge was on the south side we flip the word
            bWord = fliplr(bWord);
            shiftROIUD=true;
        elseif out.NSEW(2)
            shiftROIUD=true;
        end

        tok=regexp(bWord,'^(1+)','tokens');
        if ~isempty(tok)
            numEmptyPixels = length(tok{1}{1});
            if shiftROIUD && out.NSEW(1)
                shiftROIUD = numEmptyPixels;
            else shiftROIUD && out.NSEW(2)
                shiftROIUD = -numEmptyPixels;
            end
        else
            fprintf('FAILED TO FIND EMPTY PIXELS WHICH SHOULD EXIST')
        end



        % Repeat for LR


        %Expand ROI, say, 750 microns in the direction of the clipping. We can subtract the above. 
        %We need to know the scale factor. 
        %Then we feed back to ROIs from calller function.

    end


    %clf,imagesc(BW)