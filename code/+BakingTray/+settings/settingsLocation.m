function [settingsDir,settingsDirBackup] = settingsLocation
    % Return user settings location of the BakingTray anatomy suite to the command line
    %
    % function [settingsDir,settingsDirBackup] = settingsLocation
    %
    % Prurpose
    % Return user settings directory location of the BakingTray anatomy suite to 
    % the command line. Makes the directory if needed. Returns an empty string on 
    % error.
    % 
    % Outputs
    % settingsDir - string defining absolute path to BakingTray settings directory. 
    % settingsDirBackup - string defining absolute path to BakingTray backup settings directory.

    installDir = BakingTray.settings.installLocation;
    if isempty(installDir)
        settingsDir=[];
        return
    end

    settingsDir = fullfile(installDir,'SETTINGS');

    %Make the settings directory if needed
    if ~exist(settingsDir,'dir')
        success=mkdir(settingsDir);
        if ~success
            fprintf('FAILED TO MAKE SETTINGS DIRECTORY: %s. Check the permissions and try again\n', settingsDir);
            return
        end
    end


    % Same for the backup settings dir
    settingsDirBackup = fullfile(installDir,'SETTINGS_BACKUP');

    %Make the settings directory if needed
    if ~exist(settingsDirBackup,'dir')
        success=mkdir(settingsDirBackup);
        if ~success
            fprintf('FAILED TO MAKE BACKUP SETTINGS DIRECTORY: %s. Check the permissions and try again\n', settingsDirBackup);
            return
        end
    end
