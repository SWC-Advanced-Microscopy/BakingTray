function success=resumeAcquisition(obj,recipeFname)
    % Resume a previously terminated acquisition by loading its recipe
    %
    % function success=resumeAcquisition(obj,recipeFname)
    %
    % Purpose
    % Attempts to resume an existing acquisition, by appropriately setting
    % the section start number, end number, and so forth. If resumption fails 
    % the default recipe is loaded instead and the acquisition path is set to 
    % an empty string. This is a safety feature to ensure that the user *has*
    % to consciously decide what to do next. 
    %
    %
    % Inputs
    % recipeFname - The path to the recipe file of the acquisition we hope to 
    %         resume. name of
    %
    % Outputs
    % success - Returns true if the resumption process succeeded and
    %           the system is ready to start.
    %

    if nargin<2
        recipeFname=[];
    end

    success=false;
    if ~exist(recipeFname,'file')
        fprintf('No recipe found at %s - BT.resumeAcquisition is quitting\n', recipeFname)
        return
    end

    fprintf('Attempting to resume acquisition using recipe: %s\n', recipeFname)
    pathToRecipe = fileparts(recipeFname);

    % If pathToRecipe is empty then that must mean the user supplied only the file name with no path. 
    % Since recipeFname was found, that must mean it's in the current directory. Therefore:
    if isempty(recipeFname)
        pathToRecipe=pwd;
    end

    [containsAcquisition,details] = BakingTray.utils.doesPathContainAnAcquisition(pathToRecipe);

    if ~containsAcquisition
        fprintf(['No existing acquisition found in in directory %s.', ...
            'BT.resumeAcquisition will just load the recipe as normal\n'], pathToRecipe) %NOTE: the square bracket here was missing and MATLAB didn't spot the syntax error. When this methd was run it would hard-crash due to this
        success = obj.attachRecipe(recipeFname);
        return
    end


    % If we're here, then the path exists and acquisition should exist in the path. 
    % Attempt to set up for resuming the acquisition:

    % Finally we attempt to load the recipe
    success = obj.attachRecipe(recipeFname,true); % sets resume flag to true

    if ~success
        fprintf('Failed to resume recipe %s. Loading default.\n', recipeFname)
        obj.sampleSavePath=''; % So the user is forced to enter this before proceeding 
        obj.attachRecipe; % To load the default
        return
    end

    obj.sampleSavePath = pathToRecipe;

    % Delete the FINISHED file if it exists
    if exist(fullfile(pathToRecipe,'FINISHED'),'file')
        fprintf('Deleting FINISHED file\n')
        delete(fullfile(pathToRecipe,'FINISHED'))
    end

    % Find the last section. Did it complete and did it cut?
    lastSection = details.sections(end);
    fprintf('The last acquired section was number %d and was taken at z=%0.3f\n', ...
         lastSection.sectionNumber, lastSection.Z)

    lastSectionLogFile = fullfile(lastSection.savePath,'acquisition_log.txt');

    % If we can't find the last section directory or its log file we will proceed anyway and assume that the
    % last section was cut. So the block will be moved upwards.
    if ~exist(lastSection.savePath,'dir')
        fprintf('The last section directory is not in %s as expected.\nWill attempt to proceed and assume last section was cut.\n', ....
            lastSection.savePath)
        extraZMove = obj.recipe.mosaic.sliceThickness;
    elseif ~exist(lastSectionLogFile,'file')
        fprintf('The last section log file at %s as expected.\nWill attempt to proceed and assume last section was cut.\n', ....
            lastSectionLogFile)
        extraZMove = obj.recipe.mosaic.sliceThickness;
    else
        % If we're here, we can read the log file. We read it and determine if the lst section was cut. 
        % If it was, then we should ensure that the Z-stage is at the depth of the last completed section
        % plus one section thickness. 

        % TODO: The slicing isn't being logged for some reason. Bug in the logger? Until then: 
        extraZMove = obj.recipe.mosaic.sliceThickness;
        % TODO: If it was not we need to check if the tile scan needs finishing then cut. 
    end


    % Set the section start number and num sections
    originalNumberOfRequestedSections = obj.recipe.mosaic.numSections;
    sectionsCompleted = details.sections(end).sectionNumber;

    newSectionStartNumber = sectionsCompleted+1;
    newNumberOfRequestedSections = originalNumberOfRequestedSections-newSectionStartNumber+1;

    obj.recipe.mosaic.sectionStartNum = newSectionStartNumber;
    obj.recipe.mosaic.numSections = newNumberOfRequestedSections;


    % Check if this is an autoROI acquisition. If so, we need to populate the autoROI variables.
    if strcmp(obj.recipe.mosaic.scanmode, 'tiled: auto-ROI')
        autoROI_fname = fullfile(obj.pathToSectionDirs,obj.autoROIstats_fname);
        if ~exist(autoROI_fname,'file')
            fprintf('BT.%s can not find file %s. Failing to resume auto-ROI\n', mfilename, autoROI_fname)
            return
        end
        % Load the variable and place into the autoROI property
        varsInFile = whos('-file',autoROI_fname);
        tmp=load(autoROI_fname,varsInFile(1).name);
        obj.autoROI.stats = tmp.(varsInFile(1).name);
    end



    % So now we are safe to move the system to the last z-position plus one section
    blocking=true;
    obj.moveZto(details.sections(end).Z + extraZMove, blocking);

    % Set up the scanner as it was before. We have to manually read the scanner
    % field from the recipe, as the "live" version in the object be overwritten
    % with the current scanner settings.
    tmp=BakingTray.settings.readRecipe(recipeFname);
    if isempty(tmp)
        fprintf('BT.resumeAcquisition failed to load recipe file for applying scanner settings\n')
        return
    end
    obj.scanner.applyScanSettings(tmp.ScannerSettings)

