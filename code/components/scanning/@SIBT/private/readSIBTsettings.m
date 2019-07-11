function settings = readSIBTSettings
    % Read SIBT settings from SETTINGS/SIBT_settings.yml 
    %
    % function settings = readSIBTSettings
    %
    %
    % Purpose
    % This function parses SETTINGS/SIBT_settings.yml and creates it if does not already exist.
    %
    % The "SIBT settings" are those that describe parameters of the ScanImage scanner that are
    % unlikely to change between sessions. If no settings have been created then a default settings 
    % file is created. The settings file is then read and returned as a structure. 
    %
    %
    % Rob Campbell - SWC 2019

    settings=[];

    settingsDir = BakingTray.settings.settingsLocation;
    settingsFile = fullfile(settingsDir,'SIBT_settings.yml');

    DEFAULT_SETTINGS = default_SIBT_settings;
    if ~exist(settingsFile)
        fprintf('Can not find SIBT settings file: making default file at %s\n', settingsFile)
        BakingTray.yaml.WriteYaml(settingsFile,DEFAULT_SETTINGS);
    end

    % Now read the settings file
    settings = BakingTray.yaml.ReadYaml(settingsFile);


    % Make sure all settings that are returned are valid
    % If they are not, we replace them with the original default value

    allValid=true;

    if ~isnumeric(settings.tileAcq.tileRotate) || mod(settings.tileAcq.tileRotate,1)~=0
        fprintf('tileAcq.tileRotate should be a whole number. Setting it to "%d"\n',DEFAULT_SETTINGS.tileAcq.tileRotate)
        settings.settings.tileAcq.tileRotate = DEFAULT_SETTINGS.tileAcq.tileRotate;
        allValid=false;
    end

    if ~islogical(settings.tileAcq.tileFlipUD) && settings.tileAcq.tileFlipUD~=0 && settings.tileAcq.tileFlipUD~=1
        fprintf('tileAcq.tileFlipUD should be true or false. Setting it to "%d"\n',DEFAULT_SETTINGS.tileAcq.tileFlipUD)
        settings.settings.tileAcq.tileFlipUD = DEFAULT_SETTINGS.tileAcq.tileFlipUD;
        allValid=false;
    end

    if ~islogical(settings.tileAcq.tileFlipLR) && settings.tileAcq.tileFlipLR~=0 && settings.tileAcq.tileFlipLR~=1
        fprintf('tileAcq.tileFlipLR should be true or false. Setting it to "%d"\n',DEFAULT_SETTINGS.tileAcq.tileFlipLR)
        settings.settings.tileAcq.tileFlipLR = DEFAULT_SETTINGS.tileAcq.tileFlipLR;
        allValid=false;
    end

    if ~islogical(settings.hardware.doResetTrippedPMT) && settings.hardware.doResetTrippedPMT~=0 && settings.hardware.doResetTrippedPMT~=1
        fprintf('hardware.doResetTrippedPMT should be true or false. Setting it to "%d"\n',DEFAULT_SETTINGS.hardware.doResetTrippedPMT)
        settings.settings.hardware.doResetTrippedPMT = DEFAULT_SETTINGS.hardware.doResetTrippedPMT;
        allValid=false;
    end


    if ~allValid
        fprintf('\n ********************************************************************\n')
        fprintf(' * YOU HAVE INVALID VALUES IN %s (see above). \n', settingsFile)
        fprintf(' * You should correct these. \n', settingsFile)
        fprintf(' **********************************************************************\n')
    end


