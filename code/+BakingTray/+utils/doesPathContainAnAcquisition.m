function details = doesPathContainAnAcquisition(thisPath)
    % Returns whether a path contains an existing acquisition. Optionally provides further details
    %
    % function [details,pathToRecipe] = BakingTray.utils.doesPathContainAnAcquisition(thisPath)
    %
    % Purpose
    % Returns false if a path does not contain an acquisition. If an acquisition is present,
    % returns a structure with key details about this acquisition. This function can be used to 
    % aid in re-starting an existing acquisition and to test if it's safe to write data
    % into thisPath
    %
    %
    % Inputs
    % fname - Path to directory to test.
    %
    % Outputs
    % details - a structure contain details about the acquisition. 
    %
    % 
    % Rob Campbell - Basel, 2017


    details = false;

    if isempty(thisPath)
        return
    end

    if ~exist(thisPath,'dir')
        fprintf('BakingTray.utils.doesPathContainAnAcquisition finds directory %s does not exist. \n', thisPath)
        return
    end


    % Look for a recipe file, an acquisition log file, and a rawData directory
    acqLogFile = dir(fullfile(thisPath,'acqLog_*.txt'));
    recipeFile = dir(fullfile(thisPath,'recipe_*.yml'));
    rawDataDirPresent = exist(fullfile(thisPath,'rawData'),'dir');

    if isempty(acqLogFile) || isempty(recipeFile) || rawDataDirPresent~=7
        return
    end


    if length(acqLogFile)>1
        % Multiple acquisitions in one directory will likely cause problems and isn't supported.
        fprintf('BakingTray.utils.doesPathContainAnAcquisition finds multiple acquisition log files in %s\n',thisPath)
    end

    thisAcqLogFile = fullfile(thisPath,acqLogFile(1).name);
    details = BakingTray.utils.readAcqLogFile(thisAcqLogFile); % Details is now a structure

    % If a section number appears multiple times (e.g. because it was re-imaged) we keep only the
    % last instance
    [~,sectionInd]=unique([details.sections.sectionNumber],'last');
    details.sections = details.sections(sectionInd);

    % Append extra information to the details structure
    details.acqLogFilePath = thisAcqLogFile;
    details.containsFINISHED = exist(fullfile(thisPath,'FINISHED'), 'file')==2;

    % Pull infor out of the recipe file
    thisRecipeFile = fullfile(thisPath,recipeFile(1).name);
    tR = BakingTray.yaml.ReadYaml(thisRecipeFile);
    details.scanmode = tR.mosaic.scanmode;
    details.sliceThickness = tR.mosaic.sliceThickness;
    if isempty(findstr(details.scanmode,'auto'))
        details.autoROI=false;
    else
        details.autoROI=true;
    end


    % Loop through all raw data directories and determine the state of each
    rDataDirs = dir(fullfile(thisPath,'rawData','*-*')); % all will have one hyphen

    for ii = 1:length(rDataDirs)
        tmp=scrapeRawDataDir(fullfile(rDataDirs(ii).folder,rDataDirs(ii).name));

        %add these into the details structure
        f=find([details.sections.sectionNumber] == tmp.sectionNumber);

        tF=fields(tmp);
        for kk=1:length(tF)
            details.sections(f).(tF{kk}) = tmp.(tF{kk});
        end
    end

    % sections that are listed in the acquisition log file but were later deleted will 
    % have a lot of empty fields. Use the "completed" field to delete these from the array.
    f = arrayfun(@(x) isempty(x.completed), details.sections);
    details.sections(f)=[];



function out = scrapeRawDataDir(tDir)
    % Get info from various files in this raw data directory

    % Determine the section number from the directory name and add to the output structure
    tok=regexp(tDir,'.*rawData.*-(\d+)','tokens');
    out.sectionNumber = str2num(tok{1}{1});

    % Is there are "COMPLETED" file, indicating the section ran to completion
    if exist(fullfile(tDir,'COMPLETED'),'file')
        out.completed=true;
    else
        out.completed=false;
    end

    % Load the matrix describing the number of 
    tilePosFname = fullfile(tDir,'tilePositions.mat');
    if exist(tilePosFname,'file')
        load(tilePosFname,'positionArray')
        out.numTilePositions = size(positionArray,1);
        %Get the last imaged tile position from the array
        f=find(~isnan(positionArray(:,end)));
        out.lastImagedPosition = f(end);

    else
        fprintf('Failed to find file %s\n',tilePosFname)
        out.numTilePositions = nan;
        out.lastImagedPosition = 0;
    end


    if out.numTilePositions == out.lastImagedPosition
        out.allPositionsImaged=true;
    else
        out.allPositionsImaged=false;
    end

    % Read in the section log file and determine if the microscope sliced the sample
    fileText=fileread(fullfile(tDir,'acquisition_log.txt'));
    if isempty(findstr(fileText,'Waiting for slice to settle'))
        out.sectionSliced=false;
    else
        out.sectionSliced=true;
    end


