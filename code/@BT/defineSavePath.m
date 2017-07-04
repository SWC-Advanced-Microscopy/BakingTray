function success = defineSavePath(obj) 
    %Set up the save file names for this section based on the current recipe
    %
    % function success = BT.defineSavePath
    %
    % Purpose
    % Define the directory into which tiles will be saved and make this directory if needed.
    %
    %
    %

    if obj.currentSectionNumber<0
        fprintf('Current section number is less than zero: %d. THIS IS ODD\n', obj.currentSectionNumber)
    end


    % Make sure the path for storing raw data exists. 
    pathToRawData = fullfile(obj.sampleSavePath, obj.rawDataSubDirName);
    if ~exist(pathToRawData,'dir')
        mkdir(pathToRawData)
        fprintf('Made directory %s\n', pathToRawData)
    end

    % This is the directory into which we will place data for this section
    sectionDir = sprintf('%s-%04d', obj.recipe.sample.ID, obj.currentSectionNumber);
    saveDir = fullfile(pathToRawData,sectionDir);

    if ~exist(saveDir,'dir')
        mkdir(saveDir)
    end

    %Bail out if the save directory *still* does not exist
    if ~exist(saveDir,'dir')
        msg = sprintf('Save file directory %s is missing.',saveDir)
        obj.logMessage(inputname(1),dbstack,7,msg)
        success=false;
        return
    end

    %set the folder for logging TIFF files
    obj.currentTileSavePath = saveDir;

    success=true;
