function success = defineSavePath(obj) 
    % Set up the save file names for this section based on the current recipe and create directories as needed
    %
    % function success = BT.defineSavePath
    %
    % Purpose
    % Define the directory into which tiles will be saved and make this directory if needed.
    %
    %
    % Inputs
    % none
    %
    %
    % Outputs
    % success - true if everything was created as needed. false otherwse.

    if obj.currentSectionNumber<0
        fprintf('Current section number is less than zero: %d. THIS IS ODD\n', obj.currentSectionNumber)
    end


    % Make sure the path for storing raw data exists. 
    if ~exist(obj.pathToSectionDirs,'dir')
        mkdir(obj.pathToSectionDirs)
        fprintf('Made directory %s\n', obj.pathToSectionDirs)
    end


    % This is the directory into which we will place data for this section
    if ~exist(obj.thisSectionDir,'dir')
        mkdir(obj.thisSectionDir)
    end


    %Bail out if the save directory *still* does not exist
    if ~exist(obj.thisSectionDir,'dir')
        msg = sprintf('Save file directory %s is missing.',obj.thisSectionDir)
        obj.logMessage(inputname(1),dbstack,7,msg)
        success=false;
        obj.currentTileSavePath='';
        return
    end

    %set the folder for logging TIFF files
    obj.currentTileSavePath = obj.thisSectionDir;

    success=true;
