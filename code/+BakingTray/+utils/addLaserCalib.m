function addLaserCalib
    % Save the current laser calibration data from ScanImage into .mat file
    %
    % BakingTray.utils.addLaserCalib
    %
    % Purpose
    % Stores current laser calibration data in ScanImage to a laser calibration file
    %
    % Instructions
    % 1. Set wavelength in ScanImage and run the calibration function for the beam.
    % 2. Measure min and max power and set these in the MDF GUI under the laser.
    % 3. Confirm with power meter that the curve makes sense by looking at a few different values.
    % 4. Run BakingTray.utils.addLaserCalib

    hBT=BakingTray.getObject;
    pathToFiles = fullfile(BakingTray.settings.settingsLocation,'laser_calibration');

    laserPower.wavelength_in_nm = round(hBT.laser.targetWavelength);
    laserPower.minPower = hBT.scanner.hC.hBeams.hBeams{1}.powerFraction2PowerWattLut(1,2);
    laserPower.maxPower = hBT.scanner.hC.hBeams.hBeams{1}.powerFraction2PowerWattLut(2,2);
    laserPower.powerFraction2ModulationVoltLut = hBT.scanner.hC.hBeams.hBeams{1}.powerFraction2ModulationVoltLut;
    laserPower.dateMeasured = now;


    fname = sprintf('laserPower_%d.mat', laserPower.wavelength_in_nm);

    fprintf('Saving calibration data to %s\n',fullfile(pathToFiles,fname))
    save(fullfile(pathToFiles,fname),'laserPower')
