function applyScanSettings(obj,scanSettings)
    % SIBT.applyScanSettings
    %
    % Applies a saved set of scanSettings in order to return ScanImage to a 
    % a previous state. e.g. used to manually resume an acquisition that was 
    % terminated for some reason. Also looks for completed sections and uses
    % the last available one to set the laser power and PMT gains to whatever
    % they were last set to. 
    %
    % Inputs
    % scanSettings - the ScanImage scanSettings field from the recipe file 
    %
    % Outputs 
    % none
    %
    %

    if ~isstruct(scanSettings)
        return
    end


    % Which channels to acquire
    if iscell(scanSettings.activeChannels)
        scanSettings.activeChannels = cell2mat(scanSettings.activeChannels);
    end
    obj.hC.hChannels.channelSave = scanSettings.activeChannels;


    % The following z-stack-related settings don't strictly need to be set, 
    % since they are applied when the scanner is armed.
    obj.hC.hStackManager.stackZStepSize = scanSettings.micronsBetweenOpticalPlanes;
    obj.hC.hStackManager.numSlices = scanSettings.numOpticalSlices;

    % Set the laser power and changing power with depth. These settings may be changed again
    % right at the end, but we have this code here to ensure we have reasonable values to 
    % begin with. This is in case the code at the end of the method (which attempts to use
    % values from the most recent section) fails for some reason. 
    obj.hC.hBeams.powers = scanSettings.beamPower;
    obj.hC.hBeams.pzCustom = scanSettings.powerZAdjustType; % What sort of adjustment (if empty it's default exponential)
    obj.hC.hBeams.lengthConstants = scanSettings.beamPowerLengthConstant;
    obj.hC.hBeams.pzAdjust = scanSettings.powerZAdjust; % Bool. If true, we ramped power with depth


    % We set the scan parameters. The order in which these are set matters
    obj.hC.hRoiManager.scanZoomFactor = scanSettings.zoomFactor;
    obj.hC.hScan2D.bidirectional = scanSettings.bidirectionalScan;
    obj.hC.hRoiManager.forceSquarePixelation = scanSettings.pixEqLinCheckBox;

    obj.hC.hRoiManager.pixelsPerLine = scanSettings.pixelsPerLine;
    if ~scanSettings.pixEqLinCheckBox
        obj.hC.hRoiManager.linesPerFrame = scanSettings.linesPerFrame;
    end

    % The fill fraction affects scan angle size so we must set it before altering the 
    % scanner multipliers and offsets
    obj.hC.hScan2D.fillFractionSpatial = scanSettings.fillFractionSpatial;


    % Set the scan angle multipliers. This is likely only critical if 
    % acquiring rectangular scans.
    obj.hC.hRoiManager.scanAngleMultiplierSlow = scanSettings.slowMult;
    obj.hC.hRoiManager.scanAngleMultiplierFast = scanSettings.fastMult;
    obj.hC.hRoiManager.scanAngleShiftSlow = scanSettings.scanAngleShiftSlow;
    if scanSettings.scanMode == 'linear'
        obj.hC.hRoiManager.scanAngleShiftFast = scanSettings.scanAngleShiftFast;
    end

    % These settings will affect dwell time but not the waveform shape
    obj.hC.hScan2D.sampleRate = scanSettings.sampleRate;

    if scanSettings.scanMode == 'linear'
        obj.hC.hScan2D.pixelBinFactor = scanSettings.pixelBinFactor;
    end

    % Attempt to read the meta-data from the last saved directory to apply other settings not in the
    % recipe file. 
    rawDataDir=fullfile(obj.parent.sampleSavePath,obj.parent.rawDataSubDirName);
    sectionDirs = dir(fullfile(rawDataDir,[obj.parent.recipe.sample.ID,'*']));
    if isempty(sectionDirs)
        fprintf('applyScanSettings finds no section directories in %s. Not applying detailed scan settings\n', ...
            rawDataDir)
        return
    end

    % Find TIFF files in the last directory
    lastSectionDir = fullfile(rawDataDir,sectionDirs(end).name);
    tiffs = dir(fullfile(lastSectionDir,'*.tif'));
    if isempty(tiffs)
        fprintf('applyScanSettings finds no tiffs in directory in %s. Not applying detailed scan settings\n', ...
            lastSectionDir)
        return
    end

    % Read the ScanImage settings from the first file. In the event of a hard crash, like a power-down,
    % the last few images will be garbage so we don't read the last image. 
    % TODO: consider reading the penultimate directory instead.
    TMP=scanimage.util.opentif(fullfile(lastSectionDir,tiffs(1).name));
    hSI_Settings = TMP.SI;

    % TODO -- Setting the following from settings stored in a recent TIFF is important
    % since the user might have tweaked these things during acquisition.
    % i.e. the following is not redundant code.
    obj.hC.hPmts.gains = hSI_Settings.hPmts.gains;
    obj.hC.hBeams.powers = hSI_Settings.hBeams.powers;
    obj.hC.hBeams.pzCustom = hSI_Settings.hBeams.pzCustom;
    obj.hC.hBeams.lengthConstants = hSI_Settings.hBeams.lengthConstants;
    obj.hC.hBeams.pzAdjust = hSI_Settings.hBeams.pzAdjust;
    obj.hC.hDisplay.displayRollingAverageFactor = hSI_Settings.hDisplay.displayRollingAverageFactor;
