function logData = readAcqLogFile(fname)
    % Read an acquisition log text file from an experiment root directory
    %
    % function logData = BakingTray.utils.readAcqLogFile(fname)
    %
    % Purpose
    % Reads the acquisition log file, exposing a selection of the data within it
    % to for easier processing. Not all data in the file are read in. We only
    % read in data for which BakingTray might have a use. 
    %
    %
    % Inputs
    % fname - Path to the file to read
    %
    % 
    % Rob Campbell - Basel, 2017



    if ~exist(fname)
        fprintf('BakingTray.utils.%s failed to open file %s for reading\n', mfilename, fname)
        logData=struct;
        return
    end


    % Read whole text file in one go
    txt = fileread(fname);
    txtSplit = textscan(txt,'%s','delimiter','\n');
    txtSplit = txtSplit{1};

    % Read Z and section in the form: 2017/06/30 17:30:53 -- STARTING section number 1 (1 of 1) at z=28.7000
    sectionDetails = cellfun(@(x) regexp(x,'.*STARTING section number (\d+).*z=([\d\.]+) in directory (.*)','tokens'), txtSplit,'UniformOutput', false);
    sectionDetails(cellfun(@isempty,sectionDetails))=[]; %Wipe any empty lines


    for ii=1:length(sectionDetails)
        thisSection = sectionDetails{ii}{1};
        logData.sections(ii).sectionNumber = str2num( thisSection{1} );
        logData.sections(ii).Z = str2num( thisSection{2} );
        logData.sections(ii).savePath = thisSection{3};
    end


    % Did the laser turn off?
    if regexp(txt,'Attempting to turn off laser')
        logData.attemptedLaserShutdown=true;
    else
        logData.attemptedLaserShutdown=false;
    end

    if regexp(txt,'Laser reports it turned off')
        logData.laserTurnedOff=true;
    else
        logData.laserTurnedOff=false;
    end

