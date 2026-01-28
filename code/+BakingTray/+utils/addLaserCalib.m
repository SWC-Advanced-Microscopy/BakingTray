function addLaserCalib(beamName)
    % Save the current laser calibration data from ScanImage into .mat file
    %
    % BakingTray.utils.addLaserCalib(beamName)
    %
    % Purpose
    % Stores current laser calibration data in ScanImage to a laser calibration file.
    % This feature requires at least SI 2022.
    %
    % Inputs
    % beamName - [string] Required only if you have multiple beams. Follow on-screen 
    %         prompts as needed. 
    %
    % 
    % ** Before starting
    % Download and install the multi-photon QC repo from  
    % https://github.com/SWC-Advanced-Microscopy/multiphoton-qc/
    % You will be using the mpqc.record.power function, which will make the following
    % process a lot easier.
    %
    % 1. Start BakingTray
    % 2. Run "P=mpqc.record.power" to open the power GUI 
    %
    %
    % ** Instructions
    % 1. Open the Laser GUI in BakingTray.
    % 2. Turn on the laser and open the shutter.
    % 3. Set desired wavelength in the BakingTray laser GUI. This is copied automatically to the mpqc GUI.
    % 4. In ScanImage run the beam calibration function from the beams widget.
    % 5. Run "Measure Power Curve" in the mpqc GUI. There may be a mismatch between expected and 
    %    recorded curves. 
    % 6. Press "Calibrate ScanImage" and re-run "Measure Power Curve". There should be very 
    %    close correspondence between curves now.
    % 7. Run BakingTray.utils.addLaserCalib. This will over-write any existing calibration at
    %    the same wavelengths
    %
    % If you don't have the mpqc GUI working you can do steps 5 and 6 manually:
    % 5. Measure min and max power and set these in the MDF GUI under the laser. You can access this
    %    from the gear icon on the beams widget.
    % 6. Confirm with power meter that the curve makes sense by looking at a few different values.
    %
    %
    % NOTE:
    % If you have multiple beams in ScanImage you must specify which beam you are working 
    % with as an input argument to addLaserCalib. You will be prompted what to do under this
    % circumstance.
    %
    % You may list existing calibrations with BakingTray.utils.listLaserCalib
    %
    % Calibrations are applied by SIBT.applyLaserCalibration
    %
    % Rob Campbell - SWC 2022


 

    hBT=BakingTray.getObject;
    okToStart = false;

    % Available beam names as cell array if >1 beam otherwise a character array
    availableBeamNames = hBT.scanner.returnAvailableBeamNames;

    if length(hBT.scanner.hC.hBeams.hBeams)==1
        beamIndex = 1;
        beamName = availableBeamNames; % is a character array if only one beam
        okToStart = true;
    else
        % More than one beam
        if nargin==0
            fprintf('\nYou supplied no beam name but the system has multiple beams\n')
        else
            beamIndex = strmatch(beamName,availableBeamNames);
            if isempty(beamIndex)
                fprintf('\nSupplied beam name "%s" that does not exist.\n', beamName)
            else
                okToStart = true;
            end
        end

        if ~okToStart
            fprintf('\nTo run the function, supply a valid beam name:\n')

            for ii=1:length(availableBeamNames)
                fprintf('%d. BakingTray.utils.addLaserCalib(''%s'')\n', ii, availableBeamNames{ii})
            end

            fprintf('\n')

        end

    end


    if ~okToStart
        fprintf('\n *** CALIBRATION NOT SAVED! *** \n\n')
        return
    end


    if isempty(hBT)
        fprintf('Please start BakingTray\n')
        return
    end

    pathToFiles = fullfile(BakingTray.settings.settingsLocation,'laser_calibration');

    if exist(pathToFiles,'dir') == 0
        fprintf('Creating %s\n', pathToFiles)
        mkdir(pathToFiles)
    end

    laserPower.wavelength_in_nm = round(hBT.laser.targetWavelength);

    if laserPower.wavelength_in_nm < 1
        fprintf('\n *** PLEASE OPEN BAKINGTRAY LASER GUI AND TRY AGAIN *** \n')
        return
    end

    laserPower.minPower = hBT.scanner.hC.hBeams.hBeams{beamIndex}.powerFraction2PowerWattLut(1,2);
    laserPower.maxPower = hBT.scanner.hC.hBeams.hBeams{beamIndex}.powerFraction2PowerWattLut(2,2);
    laserPower.powerFraction2ModulationVoltLut = hBT.scanner.hC.hBeams.hBeams{beamIndex}.powerFraction2ModulationVoltLut;
    laserPower.outputRange_V = hBT.scanner.hC.hBeams.hBeams{beamIndex}.outputRange_V;
    laserPower.dateMeasured = now;
    laserPower.beamName = beamName;


    % Build the file name ensuring the beam name has no spaces

    fname = sprintf('laserPower_%s_%d.mat', strrep(beamName,' ', ''), laserPower.wavelength_in_nm);

    fprintf('Saving calibration data to %s\n',fullfile(pathToFiles,fname))
    save(fullfile(pathToFiles,fname),'laserPower')
