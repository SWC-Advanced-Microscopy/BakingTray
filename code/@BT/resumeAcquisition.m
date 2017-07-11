function success=resumeAcquisition(obj,fname)
    % Attach recipe  BT
    %
    % function success=resumeAcquisition(obj,fname)
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
    % fname - The path to the recipe file of the acquisition we hope to 
    %         resume. name of
    %
    % Outputs
    % success - Returns true if the resumption process succeeded and
    %           the system is ready to start.
    %

    if nargin<2
        fname=[];
    end

    if ~exist(fname,'file')
        success=false;
        fprintf('No recipe found at %s - BT.resumeAcquisition is quitting\n', fname)
        return
    end

    pathToRecipe = fileparts(fname);
    [containsAcquisition,details] = BakingTray.utils.doesPathContainAnAcquisition(pathToRecipe);

    if ~containsAcquisition
        fprintf(['No existing acquisition found in in directory %s.', ...
            'BT.resumeAcquisition will just load the recipe as normal\n', pathToRecipe)
        succuess = obj.attachRecipe(fname);
        return
    end


    % If we're here, then the path exists and acquisition should exist in the path. 
    % Attempt to set up for resuming the acquisition:

    % Finally we attempt to load the recipe
    success = obj.attachRecipe(fullPath,true); % sets resume flag to true

    if ~success
        fprintf('Failed to resume recipe %s. Loading default.\n', fname)
        obj.sampleSavePath=''; % So the user is forced to enter this before proceeding 
        obj.attachRecipe; % To load the default
        return
    end


    % Set the section start number and num sections
    originalNumberOfRequestedSections = obj.recipe.mosaic.numSections;
    sectionsCompleted = length(details.sections);

    newSectionStartNumber = sectionsCompleted+1;
    newNumberOfRequestedSections = originalNumberOfRequestedSections-newSectionStartNumber;

    obj.recipe.mosaic.sectionStartNum = newSectionStartNumber;
    obj.recipe.mosaic.numSections = newNumberOfRequestedSections;

    % TODO: Look in the final section and check whether all tiles were acquired


    % So now we are safe to move the system to the last z-position
    blocking=true;
    obj.moveZto(details.sections(end).Z, blocking)
