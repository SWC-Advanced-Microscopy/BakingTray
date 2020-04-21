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
    % performs the scan, then returns the scan parameters to their original values. To
    % indicate that the settings are at the lower resolution, the sample ID is changed
    % to the string "FASTPREVIEW" for the duration of the preview scan.
    %
    % 


    if ~obj.isScannerConnected 
        fprintf('No scanner connected.\n')
        return
    end

    if ~isa(obj.scanner,'SIBT') && ~isa(obj.scanner,'dummyScanner')
        fprintf('Only acquisition with ScanImage supported at the moment.\n')
        return
    end


    % ----------------------------------------------------------------------------
    %Check whether the acquisition is likely to fail in some way

    %Temporarily change the sample ID so it won't trigger the blocking of acquisition 
    %in obj.checkIfAcquisitionIsPossible; TODO: a better solution is needed for this.
    ID=obj.recipe.sample.ID;
    obj.recipe.sample.ID='FASTPREVIEW';
    [acqPossible,msg]=obj.checkIfAcquisitionIsPossible;

    if ~acqPossible
        warndlg(msg,''); %TODO: this somewhat goes against the standard procedure of having no GUI elements arise from 
                         %from the API, but it's easier in the case because of the nasty hack above with setting the sample ID name. 
        fprintf(msg)

        %Return settings to previous state
        obj.recipe.sample.ID=ID;
        return
    end

    %TODO: STORE SCAN PARAMS AND CHANGE TO FAST PARAMS
    %TODO: all this needs shim methods in SIBT
    scanPixPerLine = obj.scanner.getPixelsPerLine;
    frameAve = obj.scanner.getNumAverageFrames;

    if isa(obj.scanner, 'SIBT') && strcmp(obj.scanner.scannerType,'linear')
        binFactor = obj.scanner.hC.hScan2D.pixelBinFactor;
        sampleRate = obj.scanner.hC.hScan2D.sampleRate;
    end
    numZ = obj.recipe.mosaic.numOpticalPlanes;


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
    obj.scanner.setNumAverageFrames(1);


    %Remove any attached file logger objects (we won't need them)
    obj.detachLogObject
    obj.acquisitionInProgress=true;

    obj.scanner.disableTileSaving
    obj.currentTileSavePath=[];
    obj.currentTilePattern=obj.recipe.tilePattern; %Log the current tile pattern before starting


    obj.preAllocateTileBuffer


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
            rethrow(ME)
        end
    end



    tidyUpAfterPreview


    % Nested functions follow
    function tidyUpAfterPreview
        %Tidy up: put all settings back to what they were
        obj.scanner.disarmScanner;
        obj.acquisitionInProgress=false;

        obj.scanner.setImageSize(scanPixPerLine); % Return to original image size

        if isa(obj.scanner, 'SIBT') && strcmp(obj.scanner.scannerType,'linear')
            obj.scanner.hC.hScan2D.pixelBinFactor = binFactor;
            obj.scanner.hC.hScan2D.sampleRate = sampleRate;
        end

        obj.recipe.mosaic.numOpticalPlanes = numZ;
        obj.scanner.applyZstackSettingsFromRecipe; % Inform the scanner of the Z stack settings
        obj.recipe.sample.ID=ID;

        obj.scanner.setNumAverageFrames(frameAve);

        obj.lastTilePos.X=0;
        obj.lastTilePos.Y=0;
    end

end 
