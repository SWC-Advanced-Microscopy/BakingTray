function scanSettings = returnScanSettings(obj)
    % Return current scan settings as a structure
    %
    % OUT = SIBT.returnScanSettings
    %
    % 


    scanSettings.pixelsPerLine = obj.hC.hRoiManager.pixelsPerLine;
    scanSettings.linesPerFrame = obj.hC.hRoiManager.linesPerFrame;
    scanSettings.micronsBetweenOpticalPlanes = obj.hC.hStackManager.stackZStepSize;
    scanSettings.numOpticalSlices = obj.hC.hStackManager.numSlices;
    scanSettings.zoomFactor = obj.hC.hRoiManager.scanZoomFactor;

    scanSettings.scannerMechanicalAnglePP_fast_axis = round(range(obj.hC.hRoiManager.imagingFovDeg(:,1)),3);
    scanSettings.scannerMechanicalAnglePP_slowAxis =  round(range(obj.hC.hRoiManager.imagingFovDeg(:,2)),3);

    scanSettings.FOV_alongColsinMicrons = round(range(obj.hC.hRoiManager.imagingFovUm(:,1)),3);
    scanSettings.FOV_alongRowsinMicrons = round(range(obj.hC.hRoiManager.imagingFovUm(:,2)),3);

    scanSettings.micronsPerPixel_cols = round(scanSettings.FOV_alongColsinMicrons/scanSettings.pixelsPerLine,3);
    scanSettings.micronsPerPixel_rows = round(scanSettings.FOV_alongRowsinMicrons/scanSettings.linesPerFrame,3);

    scanSettings.framePeriodInSeconds = round(1/obj.hC.hRoiManager.scanFrameRate,3);
    scanSettings.volumePeriodInSeconds = round(1/obj.hC.hRoiManager.scanVolumeRate,3);
    scanSettings.pixelTimeInMicroSeconds = round(obj.hC.hScan2D.scanPixelTimeMean * 1E6,4);
    scanSettings.linePeriodInMicroseconds = round(obj.hC.hRoiManager.linePeriod * 1E6,4);
    scanSettings.bidirectionalScan = obj.hC.hScan2D.bidirectional;
    scanSettings.activeChannels = obj.hC.hChannels.channelSave;

    % Beam power
    scanSettings.beamPower= obj.hC.hBeams.powers;
    scanSettings.powerZAdjust = obj.hC.hBeams.pzAdjust; % Bool. If true, we ramped power with depth
    scanSettings.beamPowerLengthConstant = obj.hC.hBeams.lengthConstants; % The length constant used for ramping power
    scanSettings.powerZAdjustType = obj.hC.hBeams.pzCustom; % What sort of adjustment (if empty it's default exponential)

    % Scanner type and version
    scanSettings.scanMode= obj.scannerType;
    scanSettings.scannerID=obj.scannerID;
    scanSettings.version=obj.getVersion;

    %Record the detailed image settings to allow for things like acquisition resumption
    scanSettings.pixEqLinCheckBox = obj.hC.hRoiManager.forceSquarePixelation;
    scanSettings.slowMult = obj.hC.hRoiManager.scanAngleMultiplierSlow;
    scanSettings.fastMult = obj.hC.hRoiManager.scanAngleMultiplierFast;
