function takeRapidPreview(obj)
    % Runs one section with faster scan settings to see what the sample looks like
    %
    % function BT.takeRapidPreview
    %
    % Purpose
    % During sample set-up the user images the face of the block to determine where
    % draw the imaging area. This is called a "preview scan" and is of lower resolution
    % than the final scan. In addition, the preview scan acquires only one optical plane,
    % even if the final acquisition will involved multiple planes. This method performs
    % preview scan. It first sets scan parameters to the required lower resolution,
    % performs the scan, then returns the scan parameters to their original values.
    %
    %

    if ~obj.isScannerConnected
        fprintf('No scanner connected.\n')
        return
    end


    % ----------------------------------------------------------------------------
    %Check whether the acquisition is likely to fail in some way

    %Temporarily change the sample ID so it won't trigger the blocking of acquisition
    %in obj.checkIfAcquisitionIsPossible; TODO: a better solution is needed for this.
    [acqPossible,msg]=obj.checkIfAcquisitionIsPossible;

    if ~acqPossible
        obj.messageString = msg;
        return
    end

    % It is safest if the previous autoROI threshold is discarded when
    % a preview stack is taken. We do this regardless of the state of the
    % the acquisition mode. This avoids the possibility of an old
    % set of autoROI stats being used for a new acquisition because the
    % user didn't re-calculate the threshold.
    if ~isempty(obj.autoROI) && isfield(obj.autoROI,'stats')
        fprintf('WIPING PREVIOUS autoROI STATS!\n')
        obj.autoROI=[];
    end

    % Perform auto-ROI actions
    if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
        % Enable all channels for preview
        obj.scanner.setChannelsToDisplay(obj.scanner.getChannelsToAcquire);

        % Log which channels the user has chosen to acquire
        obj.autoROI.channelsToSave = obj.scanner.getChannelsToAcquire;
    end



    %TODO: STORE SCAN PARAMS AND CHANGE TO FAST PARAMS
    %TODO: Much of this can be in SIBT but not all.
    scanPixPerLine = obj.scanner.getPixelsPerLine;
    frameAve = obj.scanner.getNumAverageFrames;

    if isa(obj.scanner, 'SIBT') && strcmp(obj.scanner.scannerType,'linear')
        binFactor = obj.scanner.hC.hScan2D.pixelBinFactor;
        sampleRate = obj.scanner.hC.hScan2D.sampleRate;
    end
    numZ = obj.recipe.mosaic.numOpticalPlanes;
    numOverlapZ = obj.recipe.mosaic.numOverlapZPlanes;
    if strcmp(obj.scanner.scannerType,'linear')
        obj.scanner.setImageSize(128); %Set pixels per line, the method takes care of the rest
    else
        obj.scanner.setImageSize(256); %Set pixels per line, the method takes care of the rest
    end

    % This is a nasty hack for ensuring fast scanning galvos proceeds at a reasonable frame rate
    if isa(obj.scanner, 'SIBT') && strcmp(obj.scanner.scannerType,'linear')
        obj.scanner.hC.hScan2D.pixelBinFactor=12;
        obj.scanner.hC.hScan2D.sampleRate=1.25E6;
    end

    %Image just one plane without averaging
    obj.recipe.mosaic.numOpticalPlanes=1;
    obj.recipe.mosaic.numOverlapZPlanes=0;
    obj.scanner.setNumAverageFrames(1);
    obj.scanner.applyZstackSettingsFromRecipe; % Inform the scanner of the Z stack settings
    disp('APPLYING Z-SCAN SETTINGS')

    %Remove any attached file logger objects (we won't need them)
    obj.detachLogObject
    obj.acquisitionInProgress=true;
    obj.acquisitionState='preview';

    obj.scanner.disableTileSaving
    obj.currentTileSavePath=[];
    obj.populateCurrentTilePattern('isFullPreview',true); % Build and log the current tile pattern before starting
                                          % The "true" indicates we will run a full FOV preview.

    if ~obj.scanner.armScanner
        fprintf('\n\n ** FAILED TO START RAPID PREVIEW -- COULD NOT ARM SCANNER.\n\n')
    else
        %This initiates the tile scan
        try
            obj.runTileScan;
        catch ME
            obj.scanner.abortScanning;
            tidyUpAfterPreview
            fprintf('\n\n ** RAPID PREVIEW FAILED\n\n')
            report=getReport(ME);
            fprintf(report)
            rethrow(ME)
        end
    end

    tidyUpAfterPreview


    % Nested functions follow
    function tidyUpAfterPreview
        %Tidy up: put all settings back to what they were
        obj.scanner.disarmScanner;
        obj.acquisitionInProgress=false;
        obj.acquisitionState='idle';

        obj.scanner.setImageSize(scanPixPerLine); % Return to original image size

        if isa(obj.scanner, 'SIBT') && strcmp(obj.scanner.scannerType,'linear')
            obj.scanner.hC.hScan2D.pixelBinFactor = binFactor;
            obj.scanner.hC.hScan2D.sampleRate = sampleRate;
        end

        obj.recipe.mosaic.numOpticalPlanes = numZ;
        obj.recipe.mosaic.numOverlapZPlanes = numOverlapZ;
        obj.scanner.applyZstackSettingsFromRecipe; % Inform the scanner of the Z stack settings

        obj.scanner.setNumAverageFrames(frameAve);

        obj.lastTilePos.X=0;
        obj.lastTilePos.Y=0;

        % Just in case we aborted the acquisition
        obj.abortAfterSectionComplete=false;
        obj.abortAcqNow=false;
    end

end
