function applyLaserCalibration(obj,laserPower)
    % Apply a previously measured laser calibration so ScanImage reflects laser power in mW
    %
    % SIBT.applyLaserCalibration(obj,laserPower)
    %
    % Purpose
    % Apply a previously measured laser calibration to ScanImage.
    % 
    % Inputs
    % laserPower - A laser calibration structure or a path to a laser calibration structure
    %    saved to disk. If an empty array is provided, the calibration in ScanImage is wiped.


    if nargin<2
        return
    end

    if length(obj.hC.hBeams.hBeams)>1
        fprintf('SIBT.applyLaserCalibration expects just one laser. Can not proceed.\n')
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


    % Apply the LUT calibration curve
    obj.hC.hBeams.hBeams{1}.powerFraction2ModulationVoltLut = laserPower.powerFraction2ModulationVoltLut;

    % Minimum and maximum power in Watts
    powerFraction2PowerWattLut = [0, laserPower.minPower; ...
                                  1, laserPower.maxPower];
    obj.hC.hBeams.hBeams{1}.powerFraction2PowerWattLut = powerFraction2PowerWattLut;


    % Force update of the GUI
