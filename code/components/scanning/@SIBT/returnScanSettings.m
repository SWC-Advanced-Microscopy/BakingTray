function scanSettings = returnScanSettings(obj)
    % Return current scan settings as a structure
    %
    % OUT = SIBT.returnScanSettings
    %
    % Purpose
    % Read scanner settings from ScanImage and returns as a structure.
    % This needs to be sufficiently detailed to allow acquisitions to be 
    % resumed. 
    %
    % See also: SIBT.doScanSettingsMatchRecipe
    %
    % NOTE: changes to this file may require changes to --
    %    SIBT.doScanSettingsMatchRecipe
    %    SIBT.applyScanSettings
    %    recipe.recordScannerSettings (possibly)

    % Tile size, zoom, and the number of optical planes
    scanSettings.pixelsPerLine = obj.hC.hRoiManager.pixelsPerLine;
    scanSettings.linesPerFrame = obj.hC.hRoiManager.linesPerFrame;
    scanSettings.micronsBetweenOpticalPlanes = obj.hC.hStackManager.stackZStepSize;
    scanSettings.numOpticalSlices = obj.hC.hStackManager.numSlices;
    scanSettings.zoomFactor = obj.hC.hRoiManager.scanZoomFactor;
    scanSettings.objectiveResolution = obj.hC.objectiveResolution;

    % Detailed scan settings
    scanSettings.scannerType = obj.hC.hScan2D.scannerType;
    scanSettings.pixEqLinCheckBox = obj.hC.hRoiManager.forceSquarePixelation;
    scanSettings.scanAngleShiftFast = obj.hC.hRoiManager.scanAngleShiftFast;
    scanSettings.scanAngleShiftSlow = obj.hC.hRoiManager.scanAngleShiftSlow;
    scanSettings.slowMult = obj.hC.hRoiManager.scanAngleMultiplierSlow;
    scanSettings.fastMult = obj.hC.hRoiManager.scanAngleMultiplierFast; 
    scanSettings.bidirectionalScan = obj.hC.hScan2D.bidirectional;
    scanSettings.pixelBinFactor = obj.hC.hScan2D.pixelBinFactor;
    scanSettings.sampleRate = obj.hC.hScan2D.sampleRate;
    scanSettings.fillFractionSpatial = obj.hC.hScan2D.fillFractionSpatial;

    % FOV in microns
    imagingFovUm = obj.hC.hRoiManager.imagingFovUm;
    scanSettings.FOV_alongColsinMicrons = round(range(imagingFovUm(:,1)),3);
    scanSettings.FOV_alongRowsinMicrons = round(range(imagingFovUm(:,2)),3);

    scanSettings.micronsPerPixel_cols = round(scanSettings.FOV_alongColsinMicrons/scanSettings.pixelsPerLine,3);
    scanSettings.micronsPerPixel_rows = round(scanSettings.FOV_alongRowsinMicrons/scanSettings.linesPerFrame,3);

    % Useful to know but we don't use this for applying settings
    scanSettings.framePeriodInSeconds = round(1/obj.hC.hRoiManager.scanFrameRate,3);

    % Which channels to save and whether to average
    scanSettings.activeChannels = obj.hC.hChannels.channelSave;
    scanSettings.averageEveryNframes = obj.hC.hDisplay.displayRollingAverageFactor;

    % Beam power
    scanSettings.beamPower = obj.hC.hBeams.powers;
    scanSettings.beamPowerLengthConstant = obj.hC.hBeams.lengthConstants; % The length constant used for ramping power

    if obj.versionGreaterThan('2020.1')
        scanSettings.powerZAdjust = ~strcmp(char(obj.hC.hBeams.pzAdjust),'None');
        scanSettings.powerZAdjustType = obj.hC.hBeams.pzAdjust;
    else
        scanSettings.powerZAdjust = obj.hC.hBeams.pzAdjust; % Bool. If true, we ramped power with depth
        scanSettings.powerZAdjustType = obj.hC.hBeams.pzCustom; % What sort of adjustment (if empty it's default exponential)
    end

    % Scanner type and version
    scanSettings.scanMode = obj.scannerType; %resonant or linear
    scanSettings.scannerID = obj.scannerID;
    scanSettings.version = obj.getVersion;
