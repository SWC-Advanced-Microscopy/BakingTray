function success=resumeAcquisition(obj,recipeFname,varargin)
    % Resume a previously terminated acquisition by loading its recipe
    %
    % function success=resumeAcquisition(obj,recipeFname,simulate)
    %
    % Purpose
    % Attempts to resume an existing acquisition, by appropriately setting the section start number, 
    % end number, and so forth. If resumption fails the default recipe is loaded instead and the 
    % acquisition path is set to an empty string. This is a safety feature to ensure that the user 
    % *has* to consciously decide what to do next. 
    %
    % By default, a helper GUI is presented to allow the user to select the exact way the resumption
    % should occur. There are multiple options depending on why we are resuming. If 'helpergui' is
    % false, then this method by default starts imaging the sample at the last z-position, does not cut, 
    % and increments the section counter by one. Often this will not be what is needed, which is a choice
    % the user must make. The optional 'slicenow' and 'existing' input arguments allow us to specify
    % how the function will handle the resumption. These can be defined at the command line by
    % super-users, for debugging, or for novel applications. Normal users should use the GUI. 
    %
    % There is a simulated option for debugging.
    %
    %
    % Inputs (required)
    % recipeFname - The path to the recipe file of the acquisition we hope to resume.
    %
    % Inputs (param/val pairs)
    % 'helpergui' [true by default] - If true, a GUI allowing the user to choose the best resumption
    %             option is presented. This option over-rides 'slicenow' and 'existing'.
    % 'slicenow' [false by default] - Once at last section depth, moves up one section thickness 
    %         then slices.
    % 'existing' ['nothing' by default] - What do with data in the last section if the system
    %           did not cut: 
    %              a) 'nothing' - ignore the data. don't delete.
    %              b) 'reimage' - delete the data in the last section directory and re-image
    %              c) 'complete' - carry on from the last imaged tile position. [TODO- this option is functional yet]
    %   Note that if we sliced the last section, options (b) and (c) aren't possible. 
    % 'simulate' [false by default] - If true, report to screen what steps would have happened 
    %         but do not modify the state of BakingTray or move any stages.
    %
    % Outputs
    % success - Returns true if the resumption process succeeded and
    %           the system is ready to start.
    %


    success=false;

    params = inputParser;
    params.CaseSensitive = false;

    params.addParameter('helpergui', true,  @(x) islogical(x) || x==1 || x==0)
    params.addParameter('slicenow', false,  @(x) islogical(x) || x==1 || x==0)
    params.addParameter('existing', 'nothing', @(x) ischar(x) && (strcmp(x,'nothing') || strcmp(x,'reimage') ) )
    params.addParameter('simulate', false,  @(x) islogical(x) || x==1 || x==0)

    params.parse(varargin{:})
    helpergui = params.Results.helpergui;
    slicenow = params.Results.slicenow;
    existing = params.Results.existing;
    simulate = params.Results.simulate;



    % Ensure the user supplied the path to a recipe file
    if nargin<2
        fprintf('BT.resumeAcquisition requires at least one input argument\n')
        return
    end

    if exist(recipeFname)==7
        fprintf('BT.resumeAcquisition requires a recipe to be supplied as an input argument. Quitting.\n')
        return
    end

    if exist(recipeFname,'file')==0
        fprintf('No recipe found at %s - BT.resumeAcquisition is quitting\n', recipeFname)
        return
    end


    if simulate
        fprintf('Simulating resumption of acquisition using recipe: %s\n', recipeFname)
    else
        fprintf('Attempting to resume acquisition using recipe: %s\n', recipeFname)
    end

    % Hack to ensure we have a path to the file if it's in the current directory
    pathToRecipe = fileparts(recipeFname);

    % If pathToRecipe is empty then that must mean the user supplied only the file name with no path. 
    % Since recipeFname was found, that must mean it's in the current directory. Therefore:
    if isempty(pathToRecipe)
        pathToRecipe=pwd;
    end


    details = BakingTray.utils.doesPathContainAnAcquisition(pathToRecipe);

    % Bail out gracefully if this isn't an acquisition directory
    if ~isstruct(details) && details == false
         % NOTE: the square bracket in the following string concatenation was missing and MATLAB oddly 
         % didn't spot the syntax error. When this methd was run it would hard-crash due to this.
        fprintf(['No existing acquisition found in in directory %s. ', ...
            'BT.resumeAcquisition will just load the recipe as normal\n'], pathToRecipe)
        if ~simulate
            success = obj.attachRecipe(recipeFname);
        else
            fprintf('Attaching recipe %s without resuming\n', recipeFname)
        end
        return
    end

    if details.autoROI
        fprintf('auto-ROI resumption not working yet\n')
        return
    end

    % The user chooses how the resumption should proceed
    if helpergui
        [slicenow,existing] = resume_GUI_helper(obj,pathToRecipe);
        if length(slicenow)==1 && isnan(slicenow)
            return
        end
    end


    % Do not proceed if the inputs provided by the user make no sense
    if strcmp('reimage',existing) || strcmp('complete',existing)
        if slicenow
            fprintf('BT.resumeAcquisition: Can not slice the last section and then image it. Quitting.\n')
            return
        end
        if details.sections(end).sectionSliced
            fprintf('BT.resumeAcquisition: Last section was already sliced. Can not image it again as requested. Quitting.\n')
            return
        end
    end

    if strcmp('complete',existing) && details.sections(end).allPositionsImaged
        fprintf('BT.resumeAcquisition: Last section has already been completely imaged. Will simply slice and carry on.\n')
        slicenow=true;
        existing='nothing';
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

    % Move the system to the last z-position
    targetPosition = details.sections(end).Z;
    %If the last section ws sliced and we just move on to the next section then we need to
    %add one section thickness
    if slicenow==false && strcmp(existing,'nothing')
        targetPosition = targetPosition + details.sliceThickness;
    end
    if simulate
        fprintf('Move Z stage to %0.3f\n', targetPosition)
    else
        obj.moveZto(targetPosition, true); % execute blocking motion to last stage position
    end


    % Slicing and then re-imaging makes no sense, but we have checked at the top for this and 
    % so everything that follows is safe.
    if slicenow
        if simulate
            fprintf('Slicing sample\n')
        else
            obj.sliceSample
        end
    end


    if strcmp('reimage',existing)
        % We delete the directory containing the last section
        lastDirPath = details.sections(end).savePath;
        if simulate
            fprintf('Deleting last section (# %d) directory: %s\n', ...
                details.sections(end).sectionNumber, lastDirPath)
        else
            rmdir(lastDirPath,'s')
        end
        details.sections(end) = [];
    end



    % Set the section start number and num sections
    originalNumberOfRequestedSections = obj.recipe.mosaic.numSections;
    lastImagedSectionNumber = details.sections(end).sectionNumber;


    if strcmp(existing,'complete')
        newSectionStartNumber = lastImagedSectionNumber;
    else
        newSectionStartNumber = lastImagedSectionNumber+1;
    end

    newNumberOfRequestedSections = originalNumberOfRequestedSections-newSectionStartNumber+1;
    if newNumberOfRequestedSections<1
        fprintf('\n** Original number of requested sections was %d but since section start number is now %d this is not possible.\n', ...
            originalNumberOfRequestedSections, newSectionStartNumber)
        fprintf('** Resuming acquisition asking for just one section. You may modify this value as appropriate.\n\n')
        newNumberOfRequestedSections=1;
    end


    if simulate
        fprintf(['Last section directory on disk: %d\n',...
            'Set recipe.mosaic.sectionStartNum to %d\nSet recipe.mosaic.numSections to %d\n'], ...
            details.sections(end).sectionNumber, ...
            newSectionStartNumber, ...
            newNumberOfRequestedSections)
    else
        obj.recipe.mosaic.sectionStartNum = newSectionStartNumber;
        obj.recipe.mosaic.numSections = newNumberOfRequestedSections;
    end


    % %TODO -- this code is dead right now as we don't give the user the option to continue. 
    if strcmp(existing,'complete')
        if simulate
            fprintf('Resuming acquisition at tile position %d section %d\n', ...
                details.sections(end).lastImagedPosition+1, details.sections(end).sectionNumber)
        else
            hBT.currentTilePosition = details.sections(end).lastImagedPosition+1;
        end
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
