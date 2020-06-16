function success=resumeAcquisition(obj,recipeFname,simulate)
    % Resume a previously terminated acquisition by loading its recipe
    %
    % function success=resumeAcquisition(obj,recipeFname,simulate)
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
    %         resume.
    % simulate [optional, false by default] - If true, we report to screen 
    %          what steps would have happened but do not modify the state
    %          of BakingTray or move any stages.
    %
    % Outputs
    % success - Returns true if the resumption process succeeded and
    %           the system is ready to start.
    %

    if nargin<2
        fprintf('BT.resumeAcquisition requires at least one input argument\n')
        return
    end

    if nargin<3
        simulate=false;
    end

    success=false;
    if exist(recipeFname)==7
        fprintf('BT.resumeAcquisition requires a recipe to be supplied as an input argument. Quitting.\n')
        return
    end

    if exist(recipeFname,'file')==0
        fprintf('No recipe found at %s - BT.resumeAcquisition is quitting\n', recipeFname)
        return
    end


    fprintf('Attempting to resume acquisition using recipe: %s\n', recipeFname)
    pathToRecipe = fileparts(recipeFname);

    % If pathToRecipe is empty then that must mean the user supplied only the file name with no path. 
    % Since recipeFname was found, that must mean it's in the current directory. Therefore:
    if isempty(pathToRecipe)
        pathToRecipe=pwd;
    end

    [containsAcquisition,details] = BakingTray.utils.doesPathContainAnAcquisition(pathToRecipe);

    if ~containsAcquisition
         % NOTE: the square bracket in the following string concatenation was missing and MATLAB oddly 
         % didn't spot the syntax error. When this methd was run it would hard-crash due to this.
        fprintf(['No existing acquisition found in in directory %s.', ...
            'BT.resumeAcquisition will just load the recipe as normal\n'], pathToRecipe)
        if ~simulate
            success = obj.attachRecipe(recipeFname);
        else
            fprintf('Attaching recipe %s without resuming\n', recipeFname)
        end
        return
    end


    % If we're here, then the path exists and an acquisition should exist within it.
    % Attempt to set up for resuming the acquisition:

    % Finally we attempt to load the recipe
    if ~simulate
        success = obj.attachRecipe(recipeFname,true); % sets resume flag to true
    else
        success = true;
        fprintf('Attaching %s and resuming.\n', recipeFname)
    end

    if ~success
        fprintf('Failed to resume recipe %s. Loading default.\n', recipeFname)
        if ~simulate
            obj.sampleSavePath=''; % So the user is forced to enter this before proceeding 
            obj.attachRecipe; % To load the default
        else
            fprintf('Wiping sample save path and loading default recipe\n')
        end
        return
    end

    if ~simulate
        obj.sampleSavePath = pathToRecipe;
    end

    % Delete the FINISHED file if it exists
    if exist(fullfile(pathToRecipe,'FINISHED'),'file')
        fprintf('Deleting FINISHED file\n')
        if ~simulate
            delete(fullfile(pathToRecipe,'FINISHED'))
        end
    end

    % Did it complete and cut the last section?
    if details.sections(end).sectionSliced==true
        % Ensure that the Z-stage is at the depth of the last completed sectionplus one section thickness. 
        extraZMove = details.sliceThickness;
    else
        extraZMove=0;
    end


    % Set the section start number and num sections
    originalNumberOfRequestedSections = obj.recipe.mosaic.numSections;
    sectionsCompleted = details.sections(end).sectionNumber;

    newSectionStartNumber = sectionsCompleted+1;
    newNumberOfRequestedSections = originalNumberOfRequestedSections-newSectionStartNumber+1;
    if newNumberOfRequestedSections<1
        fprintf('\n** Original number of requested sections was %d but since section start number is now %d this is not possible.\n', ...
            originalNumberOfRequestedSections, newSectionStartNumber)
        fprintf('** Resuming acquisition asking for just one section. You may modify this value as appropriate.\n\n')
        newNumberOfRequestedSections=1;
    end

    if ~simulate
        obj.recipe.mosaic.sectionStartNum = newSectionStartNumber;
        obj.recipe.mosaic.numSections = newNumberOfRequestedSections;
    else
        fprintf('Set recipe.mosaic.sectionStartNum to %d\nSet recipe.mosaic.numSections to %d\n', ...
            newSectionStartNumber,newNumberOfRequestedSections)
    end


    % If this is an autoROI acquisition, populate the autoROI variables.
    if details.autoROI
        autoROI_fname = fullfile(obj.pathToSectionDirs,obj.autoROIstats_fname);
        if ~exist(autoROI_fname,'file')
            fprintf('BT.%s can not find file %s. Failing to resume auto-ROI\n', mfilename, autoROI_fname)
            return
        end
        % Load the variable and place into the autoROI property
        varsInFile = whos('-file',autoROI_fname);
        tmp=load(autoROI_fname,varsInFile(1).name);
        if ~simulate
            obj.autoROI.stats = tmp.(varsInFile(1).name);
        else
            fprintf('Apply autoROI stats from disk\n')
        end
    end



    % So now we are safe to move the system to the last z-position plus one section.
    blocking=true;
    targetPosition = details.sections(end).Z + extraZMove;
    if ~simulate
        obj.moveZto(targetPosition, blocking);
    else
        fprintf('Move Z stage to %0.3f\n', targetPosition)
    end

    % Set up the scanner as it was before. We have to manually read the scanner
    % field from the recipe, as the "live" version in the object be overwritten
    % with the current scanner settings.
    tmp=BakingTray.settings.readRecipe(recipeFname);
    if isempty(tmp)
        fprintf('BT.resumeAcquisition failed to load recipe file for applying scanner settings\n')
        return
    else
        if ~simulate
            obj.scanner.applyScanSettings(tmp.ScannerSettings)
        else
            fprintf('Applying scan settings\n')
        end
    end
