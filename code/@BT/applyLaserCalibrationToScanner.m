function applyLaserCalibrationToScanner(obj)
    % Looks for a suitable laser calibration file and applies to the scanner
    %
    % BT.applyLaserCalibrationToScanner()
    %
    % Purpose
    % The relationship between "percent power" and power at the sample varies across 
    % wavelength as tunable lasers emit different peak power across wavelength. BakingTray
    % uses its laser control class to set wavelength. Based on this and cached power 
    % calibrations taken with BakingTray.utils.addLaserCalib this method applies a 
    % wavelength-specific laser calibration when wavelength is changed. 


    verbose=false;

    if verbose
        fprintf('Entering BT.applyLaserCalibrationToScanner\n')
    end
    
    % If there is only one beam and the laser class does not have a beamName we add it now
    if isempty(obj.laser.beamName) && obj.scanner.returnNumberOfAvailableBeams == 1
        obj.laser.beamName = obj.scanner.returnAvailableBeamNames;
    end


    % This is the name of the ScanImage beam the laser GUI is controlling
    beamName = obj.laser.beamName;



    targetWavelength = round(obj.laser.targetWavelength);

    % Path to the laser calibration files
    pathToFiles = fullfile(BakingTray.settings.settingsLocation,'laser_calibration');

    if exist(pathToFiles,'dir') == 0
        if verbose
            fprintf('Found no laser calibration folder. Not setting laser power value.\n')
        end
        return
    end

    % Find all files associated with this beam
    % We first search for files that have the beam name in the file name
    fileNameGlob = sprintf('laserPower_%s_*.mat',strrep(beamName,' ', '') );
    files_new_format = dir(fullfile(pathToFiles, fileNameGlob));

    % If we don't find those, we look for files that have no laser beam name (this is the old format).
    if isempty(files_new_format)
        % Check whether we have laser calibration files in there at all,
        % because if we do they could be the old naming format!
        fileNameGlob = sprintf('laserPower_*.mat',strrep(beamName,' ', '') );
        files = dir(fullfile(pathToFiles, fileNameGlob));
        
        if ~isempty(files)
            fprintf('FOUND laser calibration files in the old naming format. Using them, but please update naming format!\n')
            fprintf('Contact devs if you are unsure what this means.\n')
        end
    else
        % But if we found the files with the beam name, we use those. 
        files = files_new_format;
    end

    if isempty(files)
        if verbose
            fprintf('Found no laser calibration files. Not setting laser power value.\n')
        end
        return
    end

    if verbose
       fprintf('Found %d laser calibration files.\n', length(files))
    end

    % See if a file matches the current wavelength to a reasonable tollerance
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


