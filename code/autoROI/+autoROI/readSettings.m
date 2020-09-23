function settings = readSettings(readFromYaml)
    % Read settings (from a yaml file if desired)
    % 
    % function settings = readSettings(readFromYaml)
    %
    % Purpose
    % Returns settings that are used by other functions. Some settings
    % are shared by multiple functions and need to be passed about. 
    % Having this settings file ensures that we don't pass around 
    % values and maybe lose track of them. 
    %
    % Inputs
    % readFromYaml - if true, reads from a yaml file located in the same dirctory
    %                as this read function. 
    %
    % TODO - currently we aren't using the YAML-reading option.
    %
    % Outputs
    % settings - A structure containing settings that read by other functions.
    %            More information on what these settings are can be found in 
    %            comments in-line with the code. 
    %
    % Rob Campbell - SWC 2020


    if nargin<1
        readFromYaml=false;
    end


    if readFromYaml
        % Look for file
        settingsFname = fullfile( fileparts(mfilename('fullpath')), 'settings.yml');

        if exist(settingsFname,'file')
            settings = yaml.ReadYaml(settingsFname);
        end

        if ~isempty(settings)
            return
        else
            % read defaults and write to file
            settings = returnSettings;
            yaml.WriteYaml(settingsFname,settings);
        end
    else
        settings = returnSettings;
    end




    function settings = returnSettings
        % The following are used in autoROI
        settings.main.borderPixSize = 4;  % How many pixels from the edge to use for background pixel estimation
        settings.main.medFiltRawImage = 5; 
        settings.main.doTiledMerge=true; %Mainly for debugging
        settings.main.tiledMergeThresh=1.05;
        settings.main.defaultThreshSD=7; %This appears both in autoROI and in runOnStackStruct
        settings.main.reCalcThreshSD_threshold=10; %If foreground/background area ratio changes by more than this factor from one section to the next we re-calc tThreshSD
        settings.main.rescaleTo=50; % Target microns per pixel to work at. autoROI uses this rescale images


        % The following are used in autoROI > binarizeImage
        settings.mainBin.removeNoise = true; % Noise removal: targets electrical noise
        settings.mainBin.medFiltBW = 5;
        settings.mainBin.primaryShape = 'disk';
        settings.mainBin.primaryFiltSize = 50; %in microns
        settings.mainBin.expansionShape = 'square';
        settings.mainBin.doExpansion = true; % Expand binarized image 
        settings.mainBin.expansionSize = 600;  %in microns

        % The following are used in autoROI > getBoundingBoxes
        settings.mainGetBB.minSizeInSqMicrons = 15000; % Chuck out ROIs smaller than this

        % The following settings are used for extending ROIs at edges where the sample seems to be clipped
        settings.clipper.edgeThreshMicrons = 250; % More than this many microns need to appear clipped at the ROI edge for it to count as clipping
        settings.clipper.growROIbyMicrons = 750; % Grow ROIs by this many microns in the direction of the clipped tissue

        % The following are used in autoROI.mergeOverlapping
        settings.mergeO.mergeThresh=1.3; %This is the default value

        % The following are used in autoROI.runOnStackStruct
        settings.stackStr.rollingThreshold=true;


        settings.autoThresh.skipMergeNROIThresh=10;
        settings.autoThresh.doBinaryExpansion=false;
        settings.autoThresh.minThreshold=2;
        settings.autoThresh.maxThreshold=12; %Increasing this produces larger ROIs but at the risk of some ballooning and flowing outside of the FOV
        settings.autoThresh.allowMaxExtensionIfFewThreshLeft=true; %see autothresh.run > getThreshAlg
        settings.autoThresh.decreaseThresholdBy=0.9; % Dangerous to go above this. Likely should leave as is. 