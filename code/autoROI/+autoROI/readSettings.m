function settings = readSettings(readFromYaml)
    % Read settings (from a yaml file if desired)
    % 
    % function settings = autoROI.readSettings(readFromYaml)
    %
    % Purpose
    % Returns settings that are common to all algorithms. Some settings
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
    % Rob Campbell - SWC 2021


    if nargin<1
        readFromYaml=false;
    end


    if readFromYaml
        % Look for file
        settingsFname = fullfile( fileparts(mfilename('fullpath')), 'common_settings.yml');

        if exist(settingsFname,'file')
            settings = BakingTray.yaml.ReadYaml(settingsFname);
        end

        if ~isempty(settings)
            return
        else
            % read defaults and write to file
            settings = returnSettings;
            BakingTray.yaml.WriteYaml(settingsFname,settings);
        end
    else
        settings = returnSettings;
    end


    % Merge in algorithm-specific settings:

    % First load alg-specific settings
    switch settings.alg
        case 'dynamicThresh_Alg'
            algSet = dynamicThresh_Alg.readSettings;
        case 'chunkedCNN_Alg'
            % pass -- no settings right now
            algSet = dynamicThresh_Alg.readSettings; %HACK -- TODO. For now read these
        case 'u_net_Alg'
            % pass -- no settings right now
            algSet = dynamicThresh_Alg.readSettings; %HACK -- TODO. For now read these
        otherwise
            fprintf('autoROI.readSettings can not find algorithm module %s\n', settings.alg)
            algSet = [];
    end

    % Second merge the two structures, skipping duplicate fields
    if ~isempty(algSet)
        tFields = fields(algSet);
        for ii=1:length(tFields)
            if isfield(settings, tFields{ii})
                fprintf('autoROI.readSettings -- WARNING -- SKIPPING DUPLICATE SETTING FIELD NAME %s\n', tFields{ii})
                continue
            end
            settings.(tFields{ii}) = algSet.(tFields{ii});
        end
    end


    % Local functions follow
    function settings = returnSettings
        % This selects the algorithm to use. It should be the name of a module directory under
        % the autoROI directory. To keep things consistent, these directories should end with the
        % string '_Alg'
        settings.alg = 'dynamicThresh_Alg';
        settings.alg = 'chunkedCNN_Alg';
        settings.alg = 'u_net_Alg';

        % The following are used in autoROI > getBoundingBoxes
        settings.mainGetBB.minSizeInSqMicrons = 15000; % Chuck out ROIs smaller than this

        % The following settings are used for extending ROIs at edges where the sample seems to be clipped
        settings.clipper.doExtension = true; % If true we attempt to expand ROIs in getBoundingBoxes. If false we do not
        settings.clipper.edgeThreshMicrons = 350; % More than this many microns need to appear clipped at the ROI edge for it to count as clipping
        settings.clipper.growROIbyMicrons = 450; % Grow ROIs by this many microns in the direction of the clipped tissue

        % The following are used in autoROI.mergeOverlapping
        settings.mergeO.mergeThresh=1.3; %This is the default value

        % The following are used by autoROI.runOnStackStruct and BT.getNextROIs
        settings.stackStr.rollingThreshold=true; % if false we use threshold of first image for the whole acquisition
        % if rolling threshold is true, the next setting is used
        settings.stackStr.nImages=5; %If zero we use the previous image. If a positive integer, we take median of this many most recent images

