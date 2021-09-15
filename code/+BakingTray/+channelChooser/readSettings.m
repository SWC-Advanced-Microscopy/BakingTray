function out = readSettings

    % TODO -- we might in future integrate into the system settings but for now let's 
    % just do like this. 


    % Get path to settings file
    t=which(['BakingTray.channelChooser.',mfilename]);

    setPath = fullfile(fileparts(t),'settings.yml');

    if ~exist(setPath,'file')
        fprintf('CAN NOT FIND SETTINGS FILE AT %s \n', setPath)
        return
    end

    rawSettings=BakingTray.yaml.ReadYaml(setPath);


    f=fields(rawSettings);
    for ii=1:length(f)
        out(ii)=rawSettings.(f{ii});
    end
