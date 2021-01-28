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
    boundingBoxArgIn = {'doPlot', ~noPlot, ...
                    'settings', settings};


    % In the first section the user should have acquired a preview that captures the whole sample
    % and has a generous border area. We therefore extract the ROIs from the whole of the first section.
    fprintf('\nDoing section %d/%d\n', 1, size(pStack.imStack,3))
    fprintf('Finding bounding box in first section\n')
    stats = autoROI(pStack, [], boundingBoxArgIn{:});
    stats.roiStats.sectionNumber=1; % This is needed because it's provided in live acquisitions
    drawnow

    if pauseBetweenSections
        set(gcf,'Name',sprintf('%d/%d',1,size(pStack.imStack,3)))
        fprintf(' -> Press return\n')
        pause
    end



    % Enter main for loop in which we process each section one at a time using the ROIs from the previous section
    for ii=2:size(pStack.imStack,3)
        fprintf('\nDoing section %d/%d\n', ii, size(pStack.imStack,3))
        pStack.sectionNumber=ii;


        thresh = autoROI.getThreshFromROIstats(stats);

        % autoROI is fed the ROI structure from the **previous section**
        % It runs the sample-detection code within these ROIs only and returns the results.
        tmp = autoROI(pStack, stats,...
            boundingBoxArgIn{:}, ...
            'tThresh',thresh);

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


    % Tidy
    if noPlot, fprintf('\n'), end

    % Reset the figure name
    set(gcf,'Name','')


    % Return optional outputs
    if nargout>0
        varargout{1}=stats;
    end
