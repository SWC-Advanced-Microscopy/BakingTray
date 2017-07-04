function settingsDir=settingsLocation
    % Return user settings location of the BakingTray anatomy suite to the command line
    %
	% function settingsDir=settingsLocation
	%
	% Prurpose
    % Return user settings directory location of the BakingTray anatomy suite to 
    % the command line. Makes the directory if needed. Returns an empty string on 
    % error.
    % 


    installDir = BakingTray.settings.installLocation;
    if isempty(installDir)
    	settingsDir=[];
        return
    end

    settingsDir = fullfile(installDir,'SETTINGS');

    %Make the settings directory if needed
    if ~exist('settingsDir')
        mkdir(settingsDir)
    end

    if ~exist(settingsDir,'dir')
        success=mkdir(settingsDir);
        if ~success
            fprintf('FAILED TO MAKE SETTINGS DIRECTORY: %s. Check the permissions and try again\n', settingsDir);
            return
        end
    end