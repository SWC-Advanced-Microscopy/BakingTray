function varargout=runOnStackStruct(pStack,noPlot,settings,tThreshSD)
    % Run the ROI-finding algorithm on a stack processed by genGroundTruthBorders
    %
    % function autoROI.test.runOnStackStruct(pStack,noPlot,settings,tThreshSD)
    %
    % Purpose
    % Simulate the behavior of an imaging system seeking to image only
    % the tissue without benefit of a low res preview scan of the area.
    % This function will be used for tweaking algorithms, benchmarking,
    % and testing. It must simulate the steps the actual microscope will
    % take and so can't "cheat" and must only use "past" data to derive
    % future behavior.
    %
    % This function just loops through the sample-detection code. It
    % doesn't implement extra steps for finding the sample. 
    %
    %
    % Inputs
    % pStack - preview stack structure
    % noPlot - false by default
    % settings - if empty or missing we get from the file
    % tThreshSD - if present, we do not run autothresh and use this threshold SD instead.
    %
    %
    % Outputs
    % stats structure
    %
    %
    % Examples TODO-- remove soon
    % TEMP  -- run CNN version: autoROI.test.runOnStackStruct(pStack,[],[],N750)
    %
    %
    % Rob Campbell - 2020 SWC




    if nargin<2 || isempty(noPlot)
        % Show result progress images as we go? (slower)
        noPlot=false;
    end

    if nargin<3 || isempty(settings)
        settings = autoROI.readSettings;
    end

    if nargin<4
        tThreshSD=[];
    end

    pauseBetweenSections=false;

    % Ensure we start at section 1
    pStack.sectionNumber = 1;

    % Step one: process the initial image (first section) and find the bounding boxes
    % for tissue within it. This is the only point where we don't use the ROIs from the
    % previous section to constrain ROI choice on then next section. Hence we are not
    % in the main for loop yet.


    % These are in the input arguments for autoROI
    boundingBoxArgIn = {'doPlot', ~noPlot};

    if ~noPlot
        clf
    end


    if isempty(tThreshSD)
        fprintf('\n ** GETTING A THRESHOLD\n')
        fprintf('%s is running auto-thresh\n', mfilename)
        [tThreshSD,at_stats]=autoROI.autothresh(pStack);
        if ~isempty(tThreshSD)
            fprintf('\nTHRESHOLD OBTAINED!\n')
            fprintf('%s\n\n',repmat('-',1,100))
        end
    else
        at_stats=[];
    end


    % In the first section the user should have acquired a preview that captures the whole sample
    % and has a generous border area. We therefore extract the ROIs from the whole of the first section.
    fprintf('\nDoing section %d/%d\n', 1, size(pStack.imStack,3))
    fprintf('Finding bounding box in first section\n')

    switch settings.alg
        case 'dynamicThresh_Alg'
            stats = autoROI(pStack, [], boundingBoxArgIn{:},'tThreshSD',tThreshSD);
        case {'chunkedCNN_Alg','u_net_Alg'}
            stats = autoROI(pStack, [], boundingBoxArgIn{:},'tNet',tThreshSD); %HACK TO GET NETWORK IN
    end

    stats.roiStats.tThreshSD_recalc=false; %Flag to signal if we had to re-calc the threshold due to increase in laser power (dynamic threshold alg only)
    stats.roiStats.sectionNumber=1; % This is needed because it's provided in live acquisitions


    if pauseBetweenSections
        set(gcf,'Name',sprintf('%d/%d',1,size(pStack.imStack,3)))
        fprintf(' -> Press return\n')
        pause
    end


    rollingThreshold=settings.stackStr.rollingThreshold; %If true we base the threshold on the last few slices

    % Enter main for loop in which we process each section one at a time using the ROIs from the previous section
    for ii=2:size(pStack.imStack,3)
        fprintf('\nDoing section %d/%d\n', ii, size(pStack.imStack,3))
        pStack.sectionNumber=ii;

        % Use a rolling threshold based on the last nImages to drive sample/background
        % segmentation in the next image. If set to zero it uses the preceeding section.
        if strcmp(settings.alg,'dynamicThresh_Alg') % TODO -- HACK -- THIS SHOULD BE FARMED OUT SOMEHOW ELSEWHERE
            nImages=5;
            if rollingThreshold==false
                % Do not update the threshold at all: use only the values derived from the first section
                thresh = stats.roiStats(1).medianBackground + stats.roiStats(1).stdBackground * stats.roiStats(end).tThreshSD;
            elseif nImages==0
                % Use the threshold from the last section: TODO shouldn't this be (ii) not (ii-1)?
                thresh = stats.roiStats(ii-1).medianBackground + stats.roiStats(ii-1).stdBackground*stats.roiStats(ii-1).tThreshSD;
            elseif ii<=nImages
                % Attempt to take the median value from the last nImages: take as many as possible 
                % until we have nImages worth of sections 
                thresh = median( [stats.roiStats.medianBackground] + [stats.roiStats.stdBackground]*stats.roiStats(end).tThreshSD);
            else
                % Take the median value from the last nImages 
                thresh = median( [stats.roiStats(end-nImages+1:end).medianBackground] + [stats.roiStats(end-nImages+1:end).stdBackground]*stats.roiStats(end).tThreshSD);
            end
        end

        % autoROI is fed the ROI structure from the **previous section**
        % It runs the sample-detection code within these ROIs only and returns the results.
        if strcmp(settings.alg,'dynamicThresh_Alg') % TODO -- HACK -- THIS SHOULD BE FARMED OUT SOMEHOW ELSEWHERE
            tmp = autoROI(pStack, stats, ...
                boundingBoxArgIn{:}, ...
                'tThreshSD',stats.roiStats(end).tThreshSD, ...
                'tThresh',thresh);
        else % HACK
            tmp = autoROI(pStack, stats, ...
                boundingBoxArgIn{:}, ...
                'tNet',tThreshSD);
        end
            

        if ~isempty(tmp)
            stats=tmp;
            % The following line is needed to simulate a live acquisition
            stats.roiStats(end).sectionNumber=pStack.sectionNumber;
            if ~noPlot
                set(gcf,'Name',sprintf('%d/%d',ii,size(pStack.imStack,3)))
                drawnow
            end
            if pauseBetweenSections
                fprintf(' -> Press return\n')
                pause
            end
        else
            break
        end

    end



    % Log aspects of the run in the output structure
    pStack.fullFOV=true; % This is true because these test stacks are full FOVs (not auto-ROI) which we use for testing

    % Did we get all sections?
    if isfield(pStack,'lastSliceWithData')
        stats.numUnprocessedSections = pStack.lastSliceWithData-length(stats.roiStats);
        if stats.numUnprocessedSections<0
            stats.numUnprocessedSections=0;
        end
        stats.lastSliceWithData=pStack.lastSliceWithData;
    else
        stats.numUnprocessedSections = size(pStack.imStack,3)-length(stats.roiStats);
        stats.lastSliceWithData=size(pStack.imStack,3);
    end



    % Add a text report to the first element
    stats.report = autoROI.test.evaluateROIs(stats,pStack);
    stats.autothreshStats = at_stats;



    % Tidy
    if noPlot, fprintf('\n'), end

    % Reset the figure name
    set(gcf,'Name','')


    % Return optional outputs
    if nargout>0
        varargout{1}=stats;
    end
