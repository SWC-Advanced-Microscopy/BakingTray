function addLaserCalib
    % Save the current laser calibration data from ScanImage into .mat file
    %
    % BakingTray.utils.addLaserCalib
    %
    % Purpose
    % Stores current laser calibration data in ScanImage to a laser calibration file.
    % This feature requires at least SI 2022.
    %
    % Instructions
    % 1. Open the Laser GUI in BakingTray.
    % 2. Turn on the laser and open the shutter.
    % 3. Set desired wavelength in the laser GUI.
    % 4. In ScanImage run the beam calibration function from the beams widget.
    % 5. Measure min and max power and set these in the MDF GUI under the laser. You can access this
    %    from the gear icon on the beams widget.
    % 6. Confirm with power meter that the curve makes sense by looking at a few different values.
    % 7. Run BakingTray.utils.addLaserCalib. This will over-write any existing calibration at
    %    the same wavelengths
    %
    % You may list existing calibrations with BakingTray.utils.listLaserCalib
    %
    % Rob Campbell - SWC 2022

    hBT=BakingTray.getObject;
    pathToFiles = fullfile(BakingTray.settings.settingsLocation,'laser_calibration');

    if exist(pathToFiles,'dir') == 0
        fprintf('Creating %s\n', pathToFiles)
        mkdir(pathToFiles)
    end

    laserPower.wavelength_in_nm = round(hBT.laser.targetWavelength);

    if laserPower.wavelength_in_nm < 1
        fprintf('\n *** PLEASE OPEN BAKINGTRAY LASER GUI AND TRY AGAIN *** \n')
    end

    laserPower.minPower = hBT.scanner.hC.hBeams.hBeams{1}.powerFraction2PowerWattLut(1,2);
    laserPower.maxPower = hBT.scanner.hC.hBeams.hBeams{1}.powerFraction2PowerWattLut(2,2);
    laserPower.powerFraction2ModulationVoltLut = hBT.scanner.hC.hBeams.hBeams{1}.powerFraction2ModulationVoltLut;
    laserPower.dateMeasured = now;


    fname = sprintf('laserPower_%d.mat', laserPower.wavelength_in_nm);

    fprintf('Saving calibration data to %s\n',fullfile(pathToFiles,fname))
    save(fullfile(pathToFiles,fname),'laserPower')
