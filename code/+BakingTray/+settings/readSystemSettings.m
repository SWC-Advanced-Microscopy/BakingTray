function settings = readSystemSettings
    % Read BakingTray system settings from SETTINGS/systemSettings.yml 
    %
    % function settings = BakingTray.settings.readSystemSettings
    %
    %
    % Purpose
    % This function parses SETTINGS/systemSettings.yml and creates it if does not already exist.
    %
    % The "system settings" are those that describe parameters of the rig that are unlikely to 
    % change between sessions. If no settings have been created then the settings directory 
    % made and a default settings file is created. The user is prompted to edit it and nothing
    % is returned. If a settings file is present and looks identical to the default on, the user 
    % is prompted to edit it and nothing is returned. Otherwise the settings file is read and 
    % returned as a structure. 
    %
    %
    % Rob Campbell - Basel 2017

    settings=[];
    systemType='bakingtray'; %This isn't in the YAML because the user should not change it
    systemVersion=0.5; %This isn't in the YAML because the user should not change it

    settingsDir = BakingTray.settings.settingsLocation;


    settingsFile = fullfile(settingsDir,'systemSettings.yml');

    DEFAULT_SETTINGS = default_BT_Settings;
    if ~exist(settingsFile)
        fprintf('Can not find system settings file: making default file at %s\n', settingsFile)
        BakingTray.yaml.WriteYaml(settingsFile,DEFAULT_SETTINGS);
    end



    settings = BakingTray.yaml.ReadYaml(settingsFile);

    %Check if the loaded settings are the same as the default settings
    if isequal(settings,DEFAULT_SETTINGS)
        fprintf('\n\n *** The settings file at %s has never been edited\n *** Press RETURN then edit the file for your system.\n', settingsFile)
        fprintf(' *** For help editing the file see: https://github.com/BaselLaserMouse/BakingTray/wiki/The-Settings-Files\n\n')
        pause
        edit(settingsFile)
        fprintf('\n\n *** Once you have finished editing the file, save it and press RETURN\n')

        pause
        settings = BakingTray.settings.readSystemSettings;
        return
    end




    % Make sure all settings that are returned are valid
    % If they are not, we replace them with the original default value

    allValid=true;

    if ~ischar(settings.SYSTEM.ID)
        fprintf('SYSTEM.ID should be a string. Setting it to "%s"\n',DEFAULT_SETTINGS.SYSTEM.ID)
        settings.SYSTEM.ID = DEFAULT_SETTINGS.SYSTEM.ID;
        allValid=false;
    end

    if ~isnumeric(settings.SYSTEM.xySpeed)
        fprintf('SYSTEM.xySpeed should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.xySpeed)
        settings.SYSTEM.xySpeed = DEFAULT_SETTINGS.SYSTEM.xySpeed;
        allValid=false;
    elseif settings.SYSTEM.xySpeed<=0
        fprintf('SYSTEM.xySpeed should be >0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.xySpeed)
        settings.SYSTEM.xySpeed = DEFAULT_SETTINGS.SYSTEM.xySpeed;
        allValid=false;
    end

    if ~isnumeric(settings.SLICER.approachSpeed)
        fprintf('SLICER.approachSpeed should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.approachSpeed)
        settings.SLICER.approachSpeed = DEFAULT_SETTINGS.SLICER.approachSpeed;
        allValid=false;
    elseif settings.SLICER.approachSpeed<=0
        fprintf('SLICER.approachSpeed should not be <=0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.approachSpeed)
        settings.SLICER.approachSpeed = DEFAULT_SETTINGS.SLICER.approachSpeed;
        allValid=false;
    end

    if ~isnumeric(settings.SLICER.vibrateRate)
        fprintf('SLICER.vibrateRate should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.vibrateRate)
        settings.SLICER.vibrateRate = DEFAULT_SETTINGS.SLICER.vibrateRate;
        allValid=false;
    elseif settings.SLICER.vibrateRate<=0
        fprintf('SLICER.vibrateRate should not be <=0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.vibrateRate)
        settings.SLICER.vibrateRate = DEFAULT_SETTINGS.SLICER.vibrateRate;
        allValid=false;
    end

    if ~isnumeric(settings.SLICER.postCutDelay)
        fprintf('SLICER.postCutDelay should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.postCutDelay)
        settings.SLICER.postCutDelay = DEFAULT_SETTINGS.SLICER.postCutDelay;
        allValid=false;
    elseif settings.SLICER.postCutDelay<0
        fprintf('SLICER.postCutDelay should not be <0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.postCutDelay)
        settings.SLICER.postCutDelay = DEFAULT_SETTINGS.SLICER.postCutDelay;
        allValid=false;
    end

    if ~isnumeric(settings.SLICER.postCutVibrate)
        fprintf('SLICER.postCutDelay should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.postCutVibrate)
        settings.SLICER.postCutVibrate = DEFAULT_SETTINGS.SLICER.postCutVibrate;
        allValid=false;
    elseif settings.SLICER.postCutVibrate<0
        fprintf('SLICER.postCutVibrate should not be <0. Setting it to %0.2f \n',DEFAULT_SETTINGS.SLICER.postCutVibrate)
        settings.SLICER.postCutVibrate = DEFAULT_SETTINGS.SLICER.postCutVibrate;
        allValid=false;
    end


    if ~allValid
        fprintf('\n ********************************************************************\n')
        fprintf(' * YOU HAVE INVALID VALUES IN %s (see above). \n', settingsFile)
        fprintf(' * You should correct these. \n', settingsFile)
        fprintf(' **********************************************************************\n')
    end


    %Add in the hard-coded settings
    settings.SYSTEM.type=systemType;
    settings.SYSTEM.version=systemVersion;
    