function varargout=autoROI(pStack,lastSectionStats,varargin)
    % autoROI
    %
    % function varargout=autoROI(pStack, 'param',val, ... )
    % 
    % Purpose
    % Automatically detect regions in the current section where there is
    % sample and find a tile-based bounding box that surrounds it. This function
    % can also be fed a bounding box list in order to use these ROIs as a guide
    % for finding the next set of boxes in the next xection. This mimics the 
    % behavior under the microscope. 
    % See: autoROI.text.runOnStackStruct
    %
    % Return results in a structure.
    %
    %
    % Inputs (Required)
    % pStack - The pStack structure. From this we extract key information such as pixel size.
    % lastSectionStats - By default the whole image is used. If this argument is 
    %               present it should be the output of autoROI from a
    %               previous section. This is empty by default. Not in input parser
    %               because adding there slows down the parser.
    %
    % Inputs (Optional param/val pairs)
    % tThresh - Threshold for tissue/no tissue. By default this is auto-calculated
    % tThreshSD - Used to do the auto-calculation of tThresh.
    % doPlot - if true, display image and overlay boxes. false by default
    % skipMergeNROIThresh - If more than this number of ROIs is found, do not attempt
    %                         to merge. Just return them. Used to speed up auto-finding.
    %                         By default this is infinity, so we always try to merge.
    % showBinaryImages - shows results from the binarization step
    % doBinaryExpansion - default from setings file. If true, run the expansion of 
    %                     binarized image routine. 
    % isAutoThresh - false by default. If autoROI is being called from autoThresh.run, then
    %                this should be true. If true, we don't expand ROIs with tissue clipping.
    % settings - the settings structure. If empty or missing, we read from the file itself
    %
    %
    % Outputs
    % stats - borders and so forth
    % binaryImageStats - detailed stats on the binary image step (see binarizeImage)
    % H - plot handles
    %
    %
    % Rob Campbell - SWC, 2019

    if nargin<2
        lastSectionStats=[];
    end

    if ~isstruct(pStack)
        fprintf('%s - First input argument must be a structure.\n',mfilename)
        return
    end

    %TODO -- temp code until we overhaul all the pStacks
    if ~isfield(pStack,'sectionNumber')
        fprintf('%s - Creating sectionNumber field and setting to 1.\n',mfilename)
        pStack.sectionNumber=1;
    end

    % Extract the image we will work with if imStack has multiple images. 
    % Otherwise we assume that the only existing image is the last obtained section.
    if size(pStack.imStack,3)>1
        im = pStack.imStack(:,:,pStack.sectionNumber);
    else
        im = pStack.imStack;
    end

    % Get size settings from pStack structure
    pixelSize = pStack.voxelSizeInMicrons;
    tileSize = pStack.tileSizeInMicrons;
    tileOverlapProportion = pStack.tileOverlapProportion;


    params = inputParser;
    params.CaseSensitive = false;

    params.addParameter('doPlot', true, @(x) islogical(x) || x==1 || x==0)
    params.addParameter('tThresh',[], @(x) isnumeric(x) && isscalar(x))
    params.addParameter('tThreshSD',[], @(x) isnumeric(x) && isscalar(x) || isempty(x))
    params.addParameter('skipMergeNROIThresh',inf, @(x) isnumeric(x) )
    params.addParameter('showBinaryImages', false, @(x) islogical(x) || x==1 || x==0)
    params.addParameter('doBinaryExpansion', [], @(x) islogical(x) || x==1 || x==0 || isempty(x))
    params.addParameter('isAutoThresh',false, @(x) islogical(x) || x==1 || x==0)
    params.addParameter('settings',autoROI.readSettings, @(x) isstruct(x) )


    params.parse(varargin{:})
    doPlot = params.Results.doPlot;
    tThresh = params.Results.tThresh;
    skipMergeNROIThresh = params.Results.skipMergeNROIThresh;
    showBinaryImages = params.Results.showBinaryImages;
    doBinaryExpansion = params.Results.doBinaryExpansion;
    isAutoThresh = params.Results.isAutoThresh;
    settings = params.Results.settings;

    % Get defaults from settings file if needed
    if isempty(doBinaryExpansion)
        doBinaryExpansion = settings.mainBin.doExpansion;
    end

    % Extract settings from setting structure
    borderPixSize = settings.main.borderPixSize;

    rescaleTo = settings.main.rescaleTo;



    % These are the arguments we feed into the binarization function
    binArgs = {'doBinaryExpansion', doBinaryExpansion, ...
                'showImages',showBinaryImages, ...
                'settings',settings};

    if size(im,3)>1
        fprintf('%s requires a single image not a stack\n',mfilename)
        return
    end


    % Remove sharp edges. This helps with artifacts associated with the missing corner tile found in test 
    % Future data do not have this problem, but we keep this correction here because the test data used to
    % develop the autoROI all have this problem.
    im = autoROI.removeCornerEdgeArtifacts(im);


    sizeIm=size(im);
    if rescaleTo>1
        %fprintf('%s is rescaling image to %d mic/pix from %0.2f mic/pix\n', mfilename, rescaleTo, pixelSize);

        sizeIm = round( sizeIm / (rescaleTo/pixelSize) );
        im = imresize(im, sizeIm,'nearest'); %Must use nearest-neighbour to avoid interpolation
        origPixelSize = pixelSize;
        pixelSize = rescaleTo;
    else
        origPixelSize = pixelSize;
    end



    % Median filter the image first. This is necessary, otherwise downstream steps may not work.
    im = medfilt2(im,[settings.main.medFiltRawImage,settings.main.medFiltRawImage]);
    im = single(im);

    if isempty(tThresh)
        % This will only run on the first section
        [tThresh,statsSD] = autoROI.autoThresh(im,settings);
    end


    % Binarize, clean, add a border around the sample
    if nargout>1
       [BW,binStats] = autoROI.binarizeImage(im,pixelSize,tThresh,binArgs{:});
    else
        BW = autoROI.binarizeImage(im,pixelSize,tThresh,binArgs{:});
    end

    % We run on the whole image
    if showBinaryImages
        disp('Press return')
        pause
    end

    containsSampleMask = []; % This is a binary image that will contain 1s in regions where there is tissue
                             % It is logged but is not generated if there are no lastSectionStats so we declare it here.
    if isempty(lastSectionStats)
        stats = autoROI.getBoundingBoxes(BW,im,pixelSize);  % Find bounding boxes
        if length(stats) < skipMergeNROIThresh
            stats = autoROI.mergeOverlapping(stats,size(im)); % Merge partially overlapping ROIs
        end

    else
        % The following does not run on the first section
        % We have provided bounding box history from previous sections and so we will pull out these sub-ROIs
        % and work on them alone

        lastROI = lastSectionStats.roiStats(end);
        if rescaleTo>1
            lastROI.BoundingBoxes = ...
                cellfun(@(x) round(x/(rescaleTo/origPixelSize)), lastROI.BoundingBoxes,'UniformOutput',false);
        end

        % Run within each ROI then afterwards consolidate results
        nT=1;

        imForThresh = zeros(size(im));
        dataMask = zeros(size(im)); % Used to correct for pixels that overlap so they don't get inflatedin value
        containsSampleMask = zeros(size(im)); % All regions of the imaged area that are above threshold
        for ii = 1:length(lastROI.BoundingBoxes)
            % Scale down the bounding boxes

            % TODO -- we run binarization each time. Otherwise boundingboxes merge don't unmerge for some reason.
            minIm = min(im(:));
            tBoundingBox = lastROI.BoundingBoxes{ii};
            tIm = autoROI.getSubImageUsingBoundingBox(im, tBoundingBox,true,minIm); % Pull out just this sub-region
            imForThresh = imForThresh + tIm;
            dataMask = dataMask + (tIm>0);

            tBW = autoROI.binarizeImage(tIm,pixelSize,tThresh,binArgs{:});
            containsSampleMask = containsSampleMask + tBW.afterExpansion;
            if isAutoThresh
                tBoundingBox = [];
            end
            tStats{ii} = autoROI.getBoundingBoxes(tBW,tIm,pixelSize,tBoundingBox);

            if ~isempty(tStats{ii})
                tStats{nT} = autoROI.mergeOverlapping(tStats{ii},size(tIm));
                nT=nT+1;
            end
        end

        imForThresh = imForThresh ./ dataMask;
        imForThresh(isnan(imForThresh))=0;

        containsSampleMask = containsSampleMask > 0; % In case of any double counting due to ROI overlap
        containsNoSampleMask = ~containsSampleMask;

        % What proportion of the imaged area is background?
        numPixelsInImage = sum(dataMask(:));
        numPixelsInBackground = containsNoSampleMask .* dataMask;
        numPixelsInBackground = sum(numPixelsInBackground(:));
        propBackground = numPixelsInBackground / numPixelsInImage;

        % If useBackgroundMask is true we use only the pixels identified as background to 
        % calculate the SD of the background. Otherwise it uses the dimmest blocks of the 
        % whole image. It turns out that the latter generally works better. 
        if settings.autoThresh.useBackgroundMask && propBackground>0.1
            settings.autoThresh.keepProp=1;
            [tThresh,statsSD] = autoROI.autoThresh(imForThresh.*containsNoSampleMask,settings);
        else
            settings.autoThresh.keepProp=0.25;
            [tThresh,statsSD] = autoROI.autoThresh(imForThresh,settings);
        end

        if ~isempty(tStats{1})

            % Collate bounding boxes across sub-regions into one "stats" structure. 
            n=1;
            for ii = 1:length(tStats)
                for jj = 1:length(tStats{ii})
                    stats(n).BoundingBox = tStats{ii}(jj).BoundingBox; %collate into one structure
                    n=n+1;
                end
            end


            % Final merge. This is in case some sample ROIs are now so close together that
            % they ought to be merged. This would not have been possible to do until this point. 
            % TODO -- possibly we can do only the final merge?

            if length(stats) < skipMergeNROIThresh
                stats = autoROI.mergeOverlapping(stats,size(im));
            end
        else
            % No bounding boxes found
            fprintf('autoROI found no bounding boxes\n')
            stats=[];
        end

    end

    % Deal with scenario where nothing was found
    if isempty(stats)
        fprintf(' ** Stats array is empty. %s is bailing out. **\n',mfilename)
        if nargout>0
            varargout{1}=[];
        end
        if nargout>1
            varargout{2}=[];
        end
        if nargout>2
            varargout{3}=im;
        end
        return

    end

    % Merge ROIs that overlap too much
    if settings.main.doTiledMerge && length(stats) < skipMergeNROIThresh
        [stats,delta_n_ROI] = ...
            autoROI.mergeOverlapping(stats, size(im), ...
            settings.main.tiledMergeThresh);
    else
        delta_n_ROI=0;
    end


    % We now expand the tight bounding boxes to larger ones that correspond to a tiled acquisition
    %Convert to a tiled ROI size 
    for ii=1:length(stats)
        [stats(ii).BoundingBox, stats(ii).BoundingBoxDetails] = ...
        autoROI.boundingBoxToTiledBox(stats(ii).BoundingBox, ...
            pixelSize, tileSize, tileOverlapProportion);
    end

    % Sort the bounding boxes along the image rows (microscope X axis).
    % This makes the order in which they will be imaged somewhat better. 
    % Not optimal, though. 
    BB = {stats.BoundingBox};
    t=reshape([BB{:}],4,length(BB))';
    [~,ind]=sortrows(t,-1);
    stats = stats(ind);


    if doPlot
        clf
        H=autoROI.overlayBoundingBoxes(im,stats);
        title('Final boxes')
    else
        H=[];
    end



    % Get the forground and background pixels within each ROI. We will later
    % use this to calculate stats on all of those pixels. 
    BoundingBoxes = {stats.BoundingBox};
    for ii=1:length(BoundingBoxes)
        tIm = autoROI.getSubImageUsingBoundingBox(im,BoundingBoxes{ii});
        tBW = autoROI.getSubImageUsingBoundingBox(BW.afterExpansion,BoundingBoxes{ii});
    end

    % Calculate the number of pixels in the bounding boxes
    nBoundingBoxPixels = zeros(1,length(BoundingBoxes));
    for ii=1:length(BoundingBoxes)
        nBoundingBoxPixels(ii) = prod(BoundingBoxes{ii}(3:4));
    end


    % Make a fresh output structure if no last section stats were 
    % provided as an input argument

    if isempty(lastSectionStats)
        out.origPixelSize = origPixelSize;
        out.rescaledPixelSize = rescaleTo;
        out.nSamples = pStack.nSamples;
        out.settings = settings;
    else
        out = lastSectionStats;
    end

    % Data from all processed sections goes here
    n=pStack.sectionNumber;
    % If this section number already exists, we delete it. This is unlikely to happen.
    % Otherwise we append.
    if isfield(out,'roiStats')
        f=find([out.roiStats.sectionNumber]==n);
        out.roiStats(f)=[];
        n=length(out.roiStats)+1;
    else
        n=1;
    end

    out.roiStats(n).BoundingBoxes = {stats.BoundingBox};
    out.roiStats(n).BoundingBoxDetails = [stats.BoundingBoxDetails];

    % If we have access to the front/left stage position for this image, we
    % add that to the bounding box details. This will be used by BakingTray. 
    % autoROI itself does not care about this. 
    if isfield(pStack,'frontLeftStageMM')
        for ii=1:length(out.roiStats(n).BoundingBoxDetails)
            out.roiStats(n).BoundingBoxDetails(ii).frontLeftStageMM = pStack.frontLeftStageMM;
        end
    end

    out.roiStats(n).tThresh = tThresh;


    % Convert bounding box sizes to meaningful units and return those.
    out.roiStats(n).BoundingBoxSqMM = nBoundingBoxPixels * (pixelSize*1E-3)^2;
    out.roiStats(n).meanBoundingBoxSqMM = mean(out.roiStats(n).BoundingBoxSqMM);
    out.roiStats(n).totalBoundingBoxSqMM = sum(out.roiStats(n).BoundingBoxSqMM);

    % What proportion of the whole FOV is covered by the bounding boxes?
    % This number is only available in test datasets. In real acquisitions with the 
    % auto-finder we won't have this number. 
    out.roiStats(n).propImagedAreaCoveredByBoundingBox = sum(nBoundingBoxPixels) / prod(sizeIm);

    out.roiStats(n).statsSD = statsSD;
    out.roiStats(n).containsSampleMask = containsSampleMask;
    out.roiStats(n).previewImage = im;

    % Finally: return bounding boxes to original size
    % If we re-scaled then we need to put the bounding box coords back into the original size
    if rescaleTo>1
        rescaleRatio = rescaleTo/origPixelSize;
        out.roiStats(n).BoundingBoxes = ...
             cellfun(@(x) round(x*rescaleRatio), out.roiStats(n).BoundingBoxes,'UniformOutput',false);
        % TODO --- the following is for testing with BT! MAYBE WRONG!
        if isfield(pStack,'frontLeftStageMM')
            for ii=1:length(out.roiStats(n).BoundingBoxDetails)

                out.roiStats(n).BoundingBoxDetails(ii).frontLeftPixel.X = ...
                        out.roiStats(n).BoundingBoxDetails(ii).frontLeftPixel.X * rescaleRatio;
                out.roiStats(n).BoundingBoxDetails(ii).frontLeftPixel.Y = ...
                        out.roiStats(n).BoundingBoxDetails(ii).frontLeftPixel.Y * rescaleRatio;

            end
        end % isfield
    end


    % Optionally return coords of each box
    if nargout>0
        varargout{1}=out;
    end

    if nargout>1
        varargout{2}=binStats;
    end

    if nargout>2
        varargout{3}=H;
    end
