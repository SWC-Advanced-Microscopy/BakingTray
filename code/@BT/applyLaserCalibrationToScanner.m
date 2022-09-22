function applyLaserCalibrationToScanner(obj)
    % Looks for a suitable laser calibration file and applies to the scanner
    %
    %



    targetWavelength = round(obj.laser.targetWavelength);

    pathToFiles = fullfile(BakingTray.settings.settingsLocation,'laser_calibration');

    if exist(pathToFiles,'dir') == 0
        return
    end


    files = dir(fullfile(pathToFiles,'laserPower_*.mat'));

    if length(files)==0
        return
    end

    % See if a file matches the current wavelength to within a reasonable amount
    wavelengthDelta = ones(1,length(files))*inf;
    for ii=1:length(files)
        tok=regexp(files(ii).name, '_(\d+)\.', 'tokens');
        filePower = str2num(tok{1}{1});

        wavelengthDelta(ii) = abs(targetWavelength-filePower);
    end

    [minW,ind] = min(wavelengthDelta);

    if minW<=20 %If we are within 20 nm we use the settings
        calibFile = files(ind).name;
        pathToCalibFile = fullfile(pathToFiles,calibFile);
        obj.scanner.applyLaserCalibration(pathToCalibFile);
    else
        fprintf('Current laser wavelength of %d nm has no corresponding calibration file\n',targetWavelength)
        obj.scanner.applyLaserCalibration([]) % Wipe any existing calibration so user is not misled
    end

