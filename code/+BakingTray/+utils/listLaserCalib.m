function listLaserCalib
    % List all laser calibration files
    %
    % BakingTray.utils.listLaserCalib
    %
    % Purpose
    % Lists to screen all laser calibration files. See BakingTray.utils.addLaserCalib for how to
    % add laser calibrations.
    %
    % Instructions
    % 1. Set wavelength in ScanImage and run the calibration function for the beam.
    % 2. Measure min and max power and set these in the MDF GUI under the laser.
    % 3. Confirm with power meter that the curve makes sense by looking at a few different values.
    % 4. Run BakingTray.utils.addLaserCalib

    pathToFiles = fullfile(BakingTray.settings.settingsLocation,'laser_calibration');


    if exist(pathToFiles,'dir') == 0
        return
    end


    files = dir(fullfile(pathToFiles,'laserPower_*.mat'));



    fprintf('\n\n')

    fprintf('Found %d laser calibration files in directory %s\n\n', length(files), pathToFiles)

    for ii=1:length(files)
        load(fullfile(pathToFiles,files(ii).name))
        fprintf('%d. %s, min power: %0.0f mW, max power: %0.0f mW, last updated: %s\n', ...
            ii, ...
            files(ii).name, ...
            laserPower.minPower*1000, ...
            laserPower.maxPower*1000, ...
            datestr(laserPower.dateMeasured,'dd/mm/yyyy'))
    end

    fprintf('\n')

