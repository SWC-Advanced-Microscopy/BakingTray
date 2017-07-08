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
        fprintf('BakingTray.utils.readAcqLogFile failed to open file %s for reading\n', fname)
        logData=struct;
        return
	end


    % Read whole text file in one go
    txt = fileread(fname);
    txtSplit = textscan(txt,'%s','delimiter','\n');
    txtSplit = txtSplit{1};

    % Read Z and section in the form: 2017/06/30 17:30:53 -- STARTING section number 1 (1 of 1) at z=28.7000
    Zdepth = cellfun(@(x) regexp(x,'.*STARTING section number (\d).*z=([\d\.]+)','tokens'), txtSplit,'UniformOutput', false);
    Zdepth(cellfun(@isempty,Zdepth))=[];


    for ii=1:length(Zdepth)
        logData.sections(ii).sectionNumber = str2num( Zdepth{ii}{1}{1} );
        logData.sections(ii).Z = str2num( Zdepth{ii}{1}{2} );
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

    % What laser was used?


