function [success,msg] = doScanSettingsMatchRecipe(obj,thisRecipe)
    % Return true if the supplied recipe file has scan settings that match the scanner's current state
    %
    % [success,msg] = SIBT.doScanSettingsMatchRecipe(thisRecipe)
    %
    % Purpose
    % Check all scan settings in the supplied recipe and confirm whether the scanner matches them.
    % IMPORTANT -- you can not feed in hBT.recipe, as this reads the
    % scanner settings from ScanImage each time these are accessed and
    % so this method always returns true. 
    %
    % Inputs
    % thisRecipe - path to a recipe file or a structure containing a recipe.a recipe object
    %
    % Outputs
    % success - true if everything matches. false otherwise
    % msg - a string stating what was found. Printed to screen if not returned.
    %
    %
    % See also: SIBT.applyScanSettings, recipe.recordScannerSettings

    msg = '';
    success=false;

    if isa(thisRecipe,'recipe')
        fprintf('thisRecipe must be a structure or a path to a recipe file\n')
        return
    end
    
    if isstr(thisRecipe)
        fname = thisRecipe;
        if exist(fname,'file')
            thisRecipe = BakingTray.yaml.ReadYaml(fname);
        else
            fprintf('Can not read recipe %s\n', fname)
            return
        end
    end

    sSet = thisRecipe.ScannerSettings;

    % Tile size, zoom, and the number of optical planes
    msg = [msg, checkSetting(sSet.pixelsPerLine, obj.hC.hRoiManager.pixelsPerLine, 'Pixels per line')];
    msg = [msg, checkSetting(sSet.linesPerFrame, obj.hC.hRoiManager.linesPerFrame, 'Lines per frame')];


    msg = [msg, checkSetting(sSet.micronsBetweenOpticalPlanes, obj.hC.hStackManager.stackZStepSize, 'Microns between optical planes')];
    msg = [msg, checkSetting(sSet.numOpticalSlices, obj.hC.hStackManager.numSlices, '# optical planes')];
    msg = [msg, checkSetting(sSet.zoomFactor, obj.hC.hRoiManager.scanZoomFactor, 'Zoom factor')];

    % Detailed scan settings
    msg = [msg, checkSetting(sSet.pixEqLinCheckBox, obj.hC.hRoiManager.forceSquarePixelation, 'Square images')];
    msg = [msg, checkSetting(sSet.scanAngleShiftFast, obj.hC.hRoiManager.scanAngleShiftFast, 'Scan angle shift fast')];
    msg = [msg, checkSetting(sSet.scanAngleShiftSlow, obj.hC.hRoiManager.scanAngleShiftSlow, 'Scan angle shift slow')];
    msg = [msg, checkSetting(sSet.slowMult, obj.hC.hRoiManager.scanAngleMultiplierSlow, 'Scan angle mult slow')];
    msg = [msg, checkSetting(sSet.fastMult, obj.hC.hRoiManager.scanAngleMultiplierFast, 'Scan angle mult fast')]; 
    msg = [msg, checkSetting(sSet.bidirectionalScan, obj.hC.hScan2D.bidirectional, 'Bidirectional scanning')];
    msg = [msg, checkSetting(sSet.pixelBinFactor, obj.hC.hScan2D.pixelBinFactor, 'Pixel bin factor')];
    msg = [msg, checkSetting(sSet.sampleRate, obj.hC.hScan2D.sampleRate, 'Sample rate')];
    msg = [msg, checkSetting(sSet.fillFractionSpatial, obj.hC.hScan2D.fillFractionSpatial, 'Spatial fill fraction')];
    msg = [msg, checkSetting(sSet.objectiveResolution, obj.hC.objectiveResolution, 'Objective resolution')];

    % FOV in microns
    %imagingFovUm = obj.hC.hRoiManager.imagingFovUm;
    %sSet.FOV_alongColsinMicrons = round(range(imagingFovUm(:,1)),3);
    %sSet.FOV_alongRowsinMicrons = round(range(imagingFovUm(:,2)),3);

    %sSet.micronsPerPixel_cols = round(sSet.FOV_alongColsinMicrons/sSet.pixelsPerLine,3);
    %sSet.micronsPerPixel_rows = round(sSet.FOV_alongRowsinMicrons/sSet.linesPerFrame,3);

    % Useful to know but we don't use this for applying settings
    %sSet.framePeriodInSeconds = round(1/obj.hC.hRoiManager.scanFrameRate,3);

    % Whether to average
    msg = [msg, checkSetting(sSet.averageEveryNframes, obj.hC.hDisplay.displayRollingAverageFactor, ' ')];

    % Beam power
    msg = [msg, checkSetting(sSet.beamPower, obj.hC.hBeams.powers, 'Laser powers')];
    msg = [msg, checkSetting(sSet.powerZAdjust, obj.hC.hBeams.pzAdjust, 'Adjust with depth')]; % Bool. If true, we ramped power with depth
    msg = [msg, checkSetting(sSet.beamPowerLengthConstant, obj.hC.hBeams.lengthConstants, 'Length constant')]; % The length constant used for ramping power


    if ~isempty(msg)
        success=false;
    else
        success = true;
    end


    if nargout<2
        fprintf(msg)
    end


function msg = checkSetting(inRecipe,inScanner,settingsName)
    % Check if settings match and if not write a message string
    % msg is empty if there is a match
    

    if isequal(inRecipe,inScanner)
        msg = '';
        return
    end

    % Build a string we can print to the CLI
    msg = sprintf(' ** %s scan settings FAILS TO MATCH.', settingsName);

    if mod(inRecipe,1)==0
        msg = sprintf('%s Recipe=%d',msg,inRecipe);
    else
        msg = sprintf('%s Recipe=%0.4f',msg,inRecipe);
    end

    if mod(inScanner,1)==0
        msg = sprintf('%s Scanner=%d\n',msg,inScanner);
    else
        msg = sprintf('%s Scanner=%0.4f\n',msg,inScanner);
    end

