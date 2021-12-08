function [settings,settingsNonHardCoded] = readSystemSettings
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
    % is returned. If a settings file is present and looks identical to the default one, the user 
    % is prompted to edit it and nothing is returned. Otherwise the settings file is read and 
    % returned as a structure. 
    %
    %
    % Rob Campbell - Basel 2017

    settings=[];


    [settingsDir,backupSetingsDir] = BakingTray.settings.settingsLocation;


    settingsFname = 'systemSettings.yml';
    settingsFile = fullfile(settingsDir,settingsFname);

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


    % Pull in values from the default settings that are missing in the user settings file.
    f0 = fields(DEFAULT_SETTINGS);
    addedDefaultValue = false;
    for ii = 1:length(f0);
        f1 = fields(DEFAULT_SETTINGS.(f0{ii}));

        % Create missing structure if necessary (unlikely to ever be the case)
        if ~isfield(settings,f0{ii});
            settings.(f0{ii}) = [];
        end

        for jj = 1:length(f1)
            if ~isfield(settings.(f0{ii}), f1{jj})
                addedDefaultValue = true;
                fprintf('\n\n Adding missing default setting "%s.%s" from default_BT_Settings.m\n', ...
                    (f0{ii}), f1{jj})
                settings.(f0{ii}).(f1{jj}) = DEFAULT_SETTINGS.(f0{ii}).(f1{jj});
            end
        end
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


    if ~isnumeric(settings.SYSTEM.homeZjackOnZeroMove)
        fprintf('SYSTEM.homeZjackOnZeroMove should be a number. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SYSTEM.homeZjackOnZeroMove)
        settings.SYSTEM.homeZjackOnZeroMove = DEFAULT_SETTINGS.SYSTEM.homeZjackOnZeroMove;
        allValid=false;
    elseif settings.SYSTEM.homeZjackOnZeroMove~=0 && settings.SYSTEM.homeZjackOnZeroMove~=1
        fprintf('SYSTEM.homeZjackOnZeroMove should be 0 or 1. Setting it to "%s" \n', ...
            DEFAULT_SETTINGS.SYSTEM.homeZjackOnZeroMove)
        settings.SYSTEM.homeZjackOnZeroMove = DEFAULT_SETTINGS.SYSTEM.homeZjackOnZeroMove;
        allValid=false;
    end


    if ~ischar(settings.SYSTEM.dominantTilingDirection)
        fprintf('SYSTEM.dominantTilingDirection should be a character. Setting it to %s \n', ...
            DEFAULT_SETTINGS.SYSTEM.dominantTilingDirection)
        settings.SYSTEM.dominantTilingDirection = DEFAULT_SETTINGS.SYSTEM.dominantTilingDirection;
        allValid=false;
    elseif ~strcmpi(settings.SYSTEM.dominantTilingDirection,'y') ~=0 && ~strcmpi(settings.SYSTEM.dominantTilingDirection,'x')
        fprintf('SYSTEM.dominantTilingDirection should be x or y. Setting it to %s \n', ...
            DEFAULT_SETTINGS.SYSTEM.dominantTilingDirection)
        settings.SYSTEM.dominantTilingDirection = DEFAULT_SETTINGS.SYSTEM.dominantTilingDirection;
        allValid=false;
    end


    if ~isnumeric(settings.SYSTEM.bladeXposAtSlideEnd)
        fprintf('SYSTEM.bladeXposAtSlideEnd should be a number. Setting it to %0.2f \n',DEFAULT_SETTINGS.SYSTEM.bladeXposAtSlideEnd)
        settings.SYSTEM.bladeXposAtSlideEnd = DEFAULT_SETTINGS.SYSTEM.bladeXposAtSlideEnd;
        allValid=false;
    end


    if length(settings.SYSTEM.slideFrontLeft) ~= 2
        fprintf('SYSTEM.slideFrontLeft should be a vector length 2. Setting it to default value\n')
        settings.SYSTEM.slideFrontLeft = DEFAULT_SETTINGS.SYSTEM.slideFrontLeft;
        allValid=false;
    end


    if ~isnumeric(settings.SYSTEM.slideFrontLeft{1}) || ~isnumeric(settings.SYSTEM.slideFrontLeft{2})
        fprintf('SYSTEM.slideFrontLeft should be a number. Setting it to default value\n')
        settings.SYSTEM.slideFrontLeft = DEFAULT_SETTINGS.SYSTEM.slideFrontLeft;
        allValid=false;
    end


    if ~ischar(settings.SYSTEM.defaultSavePath)
        fprintf('SYSTEM.defaultSavePath should be a character string. Setting it to "%s" \n', ...
            DEFAULT_SETTINGS.SYSTEM.defaultSavePath)
        settings.SYSTEM.defaultSavePath = DEFAULT_SETTINGS.SYSTEM.defaultSavePath;
    elseif ~exist(settings.SYSTEM.defaultSavePath ,'dir')
        fprintf('SYSTEM.defaultSavePath should be a valid directory path. Setting it to "%s" \n', ...
            DEFAULT_SETTINGS.SYSTEM.defaultSavePath)
        settings.SYSTEM.defaultSavePath = DEFAULT_SETTINGS.SYSTEM.defaultSavePath;
    end


    if ~isnumeric(settings.SLICER.approachSpeed)
        fprintf('SLICER.approachSpeed should be a number. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.approachSpeed)
        settings.SLICER.approachSpeed = DEFAULT_SETTINGS.SLICER.approachSpeed;
        allValid=false;
    elseif settings.SLICER.approachSpeed<=0
        fprintf('SLICER.approachSpeed should not be <=0. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.approachSpeed)
        settings.SLICER.approachSpeed = DEFAULT_SETTINGS.SLICER.approachSpeed;
        allValid=false;
    end


    if ~isnumeric(settings.SLICER.vibrateRate)
        fprintf('SLICER.vibrateRate should be a number. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.vibrateRate)
        settings.SLICER.vibrateRate = DEFAULT_SETTINGS.SLICER.vibrateRate;
        allValid=false;
    elseif settings.SLICER.vibrateRate<=0
        fprintf('SLICER.vibrateRate should not be <=0. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.vibrateRate)
        settings.SLICER.vibrateRate = DEFAULT_SETTINGS.SLICER.vibrateRate;
        allValid=false;
    end


    if ~isnumeric(settings.SLICER.postCutDelay)
        fprintf('SLICER.postCutDelay should be a number. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.postCutDelay)
        settings.SLICER.postCutDelay = DEFAULT_SETTINGS.SLICER.postCutDelay;
        allValid=false;
    elseif settings.SLICER.postCutDelay<0
        fprintf('SLICER.postCutDelay should not be <0. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.postCutDelay)
        settings.SLICER.postCutDelay = DEFAULT_SETTINGS.SLICER.postCutDelay;
        allValid=false;
    end


    if ~isnumeric(settings.SLICER.postCutVibrate)
        fprintf('SLICER.postCutDelay should be a number. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.postCutVibrate)
        settings.SLICER.postCutVibrate = DEFAULT_SETTINGS.SLICER.postCutVibrate;
        allValid=false;
    elseif settings.SLICER.postCutVibrate<0
        fprintf('SLICER.postCutVibrate should not be <0. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.postCutVibrate)
        settings.SLICER.postCutVibrate = DEFAULT_SETTINGS.SLICER.postCutVibrate;
        allValid=false;
    end


    if ~isnumeric(settings.SLICER.defaultYcutPos)
        fprintf('SYSTEM.defaultYcutPos should be a number. Setting it to %0.2f \n', ...
            DEFAULT_SETTINGS.SLICER.defaultYcutPos)
        settings.SLICER.defaultYcutPos = DEFAULT_SETTINGS.SLICER.defaultYcutPos;
        allValid=false;
    end


    if ~allValid
        fprintf('\n ********************************************************************\n')
        fprintf(' * YOU HAVE INVALID VALUES IN %s (see above). \n', settingsFile)
        fprintf(' * They have been replaced with valid defaults. \n')
        fprintf(' **********************************************************************\n')
    end



    % If there are missing or invalid values we will replace these in the settings file as well as making
    % a backup copy of the original file.
    if ~allValid || addedDefaultValue
       % Copy file
       backupFname = fullfile(backupSetingsDir, [datestr(now, 'yyyy_mm_dd__HH_MM_SS_'),settingsFname]);
       fprintf('Making backup of settings file at %s\n', backupFname)
       copyfile(settingsFile,backupFname)

       % Write the new file to the settings location
       fprintf('Replacing settings file with updated version\n')
       BakingTray.yaml.WriteYaml(settingsFile,settings);
    end


    settingsNonHardCoded=settings;
    %Add in the hard-coded settings or extra info that we never want the user change
    settings.SYSTEM.type='bakingtray';

    % Git info will make up the version information
    g=BakingTray.utils.getGitInfo;
    systemVersion = sprintf('branch=%s  commit=%s', g.branch, g.hash);
    settings.SYSTEM.version=systemVersion;
