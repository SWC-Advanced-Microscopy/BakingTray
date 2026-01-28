function applyLaserCalibration(obj,laserPower)
    % Apply a previously measured laser calibration so ScanImage reflects laser power in mW
    %
    % SIBT.applyLaserCalibration(obj,laserPower)
    %
    % Purpose
    % The relationship between "percent power" and power at the sample varies across 
    % wavelength as tunable lasers emit different peak power across wavelength. BakingTray
    % uses its laser control class to set wavelength. Based on this and cached power 
    % calibrations taken with BakingTray.utils.addLaserCalib this method applies a 
    % wavelength-specific laser calibration when wavelength is changed. 
    %
    % 
    % Inputs
    % laserPower - A laser calibration structure or a path to a laser calibration structure
    %    saved to disk. If an empty array is provided, the calibration in ScanImage is wiped.
    %
    % Outputs
    % none
    %
    % Rob Campbell, SWC
    %
    % See also:
    % BT.applyLaserCalibrationToScanner (which calls this method)
    % BakingTray.utils.addLaserCalib
    % BakingTray.utils.listLaserCalib


    if nargin<2
        return
    end

    if ischar(laserPower) && exist(laserPower,'file')>0
        load(laserPower)
    else
        fprintf('SIBT.applyLaserCalibration can not load file %s\n', laserPower)
        laserPower = [];
    end

    if isempty(laserPower)
        fprintf('Removing laser calibration\n')
        obj.hC.hBeams.hBeams{1}.powerFraction2ModulationVoltLut = [];
        obj.hC.hBeams.hBeams{1}.powerFraction2PowerWattLut = [];
        return
    end

    beamIndex = 1;

    % Apply the LUT calibration curve
    obj.hC.hBeams.hBeams{beamIndex}.powerFraction2ModulationVoltLut = laserPower.powerFraction2ModulationVoltLut;

    % Minimum and maximum power in Watts
    powerFraction2PowerWattLut = [0, laserPower.minPower; ...
                                  1, laserPower.maxPower];
    obj.hC.hBeams.hBeams{beamIndex}.powerFraction2PowerWattLut = powerFraction2PowerWattLut;


    % If the outputRange was saved too (prior to October 3rd 2025 they were not, we apply)
    if isfield(laserPower,'outputRange_V')
        obj.hC.hBeams.hBeams{beamIndex}.outputRange_V = laserPower.outputRange_V;
    end

