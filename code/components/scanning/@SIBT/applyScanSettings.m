function applyScanSettings(obj,scanSettings)
    % SIBT.applyScanSettings
    %
    % Applies a saved set of scanSettings in order to return ScanImage to a 
    % a previous state. e.g. used to manually resume an acquisition that was 
    % terminated for some reason.
    %

    if ~isstruct(scanSettings)
        return
    end

    % The following z-stack-related settings don't strictly need to be set, 
    % since they are applied when the scanner is armed.
    obj.hC.hStackManager.stackZStepSize = scanSettings.micronsBetweenOpticalPlanes;
    obj.hC.hStackManager.numSlices = scanSettings.numOpticalSlices;

    % Set the laser power and changing power with depth
    obj.hC.hBeams.powers = scanSettings.beamPower;
    obj.hC.hBeams.pzCustom = scanSettings.powerZAdjustType; % What sort of adjustment (if empty it's default exponential)
    obj.hC.hBeams.lengthConstants = scanSettings.beamPowerLengthConstant;
    obj.hC.hBeams.pzAdjust = scanSettings.powerZAdjust; % Bool. If true, we ramped power with depth

    % Which channels to acquire
    if iscell(scanSettings.activeChannels)
        scanSettings.activeChannels = cell2mat(scanSettings.activeChannels);
    end
    obj.hC.hChannels.channelSave = scanSettings.activeChannels;


    % We set the scan parameters. The order in which these are set matters
    obj.hC.hRoiManager.scanZoomFactor = scanSettings.zoomFactor;
    obj.hC.hScan2D.bidirectional = scanSettings.bidirectionalScan;
    obj.hC.hRoiManager.forceSquarePixelation = scanSettings.pixEqLinCheckBox;

    obj.hC.hRoiManager.pixelsPerLine = scanSettings.pixelsPerLine;
    if ~scanSettings.pixEqLinCheckBox
        obj.hC.hRoiManager.linesPerFrame = scanSettings.linesPerFrame;
    end

    % Set the scan angle multipliers. This is likely only critical if 
    % acquiring rectangular scans.
    obj.hC.hRoiManager.scanAngleMultiplierSlow = scanSettings.slowMult;
    obj.hC.hRoiManager.scanAngleMultiplierFast = scanSettings.fastMult;
