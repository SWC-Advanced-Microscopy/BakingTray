function applyScanSettings(obj,scanSettings)
    % SIBT.applyScanSettings
    %
    % Applies a saved set of scanSettings in order to return ScanImage to a 
    % a previous state. e.g. used to manually resume an acquisition that was 
    % terminated for some reason. 
    %
    % Inputs
    % scanSettings - the ScanImage scanSettings field from the recipe file 

    if ~isstruct(scanSettings)
        return
    end

    % The following z-stack-related settings don't strictly need to be set, 
    % since they are applied when the scanner is armed.
    obj.hC.hStackManager.stackZStepSize = scanSettings.micronsBetweenOpticalPlanes;
    obj.hC.hStackManager.numSlices = scanSettings.numOpticalSlices;

    % Set the laser power and changing power with depth
    % (below we attempt to set some of these values to those used in the last acquired directory)
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


    % Attempt to read the meta-data from the last saved directory to apply other settings not in the
    % recipe file. 
    rawDataDir=fullfile(obj.parent.sampleSavePath,obj.parent.rawDataSubDirName);
    sectionDirs = dir(fullfile(rawDataDir,[obj.parent.recipe.sample.ID,'*']));
    if isempty(sectionDirs)
        fprintf('applyScanSettings finds no section directories in %s. Not applying detailed scan settings\n', ...
            rawDataDir)
        return
    end

    % Find tif files in the last directory
    lastSectionDir = fullfile(rawDataDir,sectionDirs(end).name);
    tiffs = dir(fullfile(lastSectionDir,'*.tif'));
    if isempty(tiffs)
        fprintf('applyScanSettings finds no tiffs in directory in %s. Not applying detailed scan settings\n', ...
            lastSectionDir)
        return
    end

    % Read the ScanImage settings from this file
    TMP=scanimage.util.opentif(fullfile(lastSectionDir,tiffs(end).name));
    hSI_Settings = TMP.SI;

    % Apply the important settings to the running instance of ScanImage

    obj.hC.hPmts.gains = hSI_Settings.hPmts.gains;

    obj.hC.hBeams.powers = hSI_Settings.hBeams.powers;
    obj.hC.hBeams.pzCustom = hSI_Settings.hBeams.pzCustom;
    obj.hC.hBeams.lengthConstants = hSI_Settings.hBeams.lengthConstants;
    obj.hC.hBeams.pzAdjust = hSI_Settings.hBeams.pzAdjust;

    obj.hC.hFastZ.enable = hSI_Settings.hFastZ.enable;
    obj.hC.hDisplay.displayRollingAverageFactor = hSI_Settings.hDisplay.displayRollingAverageFactor;
