function readLaserPowerSettingsFile(obj)
    % Read the settings file that is used to convert photodiode voltage to power at sample.
    % Updates the property "powerCoefs". No inputs or outputs. 
    % This method is called by the laser_view constructor.
    %
    % The file should be in the main BakingTray SETTINGS directory and be 
    % called "laserPowerLookUp.yml". It should be in this format:
    %
    %linear:
    %  b0: -6
    %  b1: 83.9 
    %lambdascale:
    %  b0: 0
    %  b1: 0  
    %  b2: 0
    %
    % 
    % You can generate these fits as follows:
    % 1. Set laser power to, say, 20% in ScanImage
    % 2. Set the power meter to, say, 920nm, an record power at sample and photodiode voltage
    %    at a range of wavelengths *without changing the power meter wavelength value*. This
    %    should produce a straight line and you can obtain a slope and intercept. These values
    %    will be linear.b0 and linear.b1
    % 3. Repeat the wavelength series in (2) at 20% power but now change the set wavelength on 
    %    the power meter. This will generate a curve. Fit this with a second order regression. 
    %    The three coefs go in lambdascale. 
    % 

    % Example values
    % linear (first value is 920 nm)
    % x1 = [0.743, 1.033, 1.082, 1.170, 1.214];
    % y1 = [56.7,   77.3,  84.7,  91.3, 94.5];
    % l1 = [920,     850,   825,   800, 780];
    %
    % lamba scale
    % x2 = [0.738, 0.866, 0.980, 1.053, 1.181, 1.221];
    % y2 = [   52,     62,   74,    84,   109,   119];
    % l2 = [920, 900, 880    850,   800, 780];

    % TODO -- At the moment user is responsible for calculating the above. In future we could
    %         make a tool to do this. 

    % TODO -- not yet implemented the lambda scaling



    settingsPowerFname = 'laserPowerLookUp.yml';
    fullFn_LaserPower = fullfile(BakingTray.settings.settingsLocation, settingsPowerFname);

    % Bail out silently if the file is missing
    if ~exist(fullFn_LaserPower,'file')
        return
    end

   % Bail out silently if the file is present but coefs for the linear fit are both zero
    settings = BakingTray.yaml.ReadYaml(fullFn_LaserPower);

    if settings.linear.b0==0 && settings.linear.b1==0
        return
    end


    % If we are here, the file is present and has sensible numbers. We therefore
    % add these to the obj.powerCoefs property of laser_view
    f = fields(settings);
    for ii=1:length(f)
        obj.powerCoefs.(f{ii}) = settings.(f{ii});
    end
