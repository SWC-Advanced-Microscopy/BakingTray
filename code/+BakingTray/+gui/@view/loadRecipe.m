function loadRecipe(obj,~,~,fullPath)
    % Loads a new recipe and initiates resumption of a previous acquisition if necessary
    %
    % Behavior
    % If a fourth argument is provided and it is a path to a file, this is treated, 
    % as a recipe to be loaded. If the fourth argument is a directory, it is treated as 
    % the path which uigetfile opens. If the fourth argument is not supplied, we start
    % uigetfile in the BakingTray settings directory
    %

    % Load recipe button callback -- loads a new recipe from disk
    if nargin<4
    	fullPath = [];
        pathForUIgetFile = [];
    end

    if ~isempty(fullPath) && ischar(fullPath) && exist(fullPath,'file')
    	% Then fullpath is a path to a file and we want the absolute path to it
    	% This is potentially accident prone, but the user can not call this method this way. 
  		absPath = fileparts(fullPath);
    end


    if ~isempty(fullPath) && ischar(fullPath) && exist(fullPath,'dir')
    	pathForUIgetFile = fullPath;
    elseif isempty(fullPath)
    	pathForUIgetFile = BakingTray.settings.settingsLocation; 	
    end

    
    if ~isempty(pathForUIgetFile)
        [fname,absPath] = uigetfile('*.yml','Choose a recipe',pathForUIgetFile);

        if fname==0
            % if the user hits cancel
            return
        end

        fullPath = fullfile(absPath,fname);
    end


    if ~exist(fullPath,'file')
        return
    end

    %Does this path already contain an acquisition?
    obj.button_recipe.String='LOADING';
    obj.button_recipe.ForegroundColor='r';
    drawnow 
    disp('Looking for acquisition')
    details = BakingTray.utils.doesPathContainAnAcquisition(absPath);
    obj.button_recipe.String='Recipe';
    obj.button_recipe.ForegroundColor='k';
    
    doResume=false;
    if isstruct(details)
        reply=questdlg(sprintf('Resume acquisition in %s?',absPath),'');
        if strcmpi(reply,'yes')
            doResume=true;
        end

        % Do nothing if the user presses cancel or closes the window
        if  strcmpi(reply,'no') || strcmpi(reply,'cancel') || isempty(reply)
            return
        end
    end


    % NOTE - if the recipe is attached using the API (the model) then it will not trigger
    % detach and attach of the listeners and so the GUI will stop updating:
    % https://github.com/SainsburyWellcomeCentre/BakingTray/issues/268
    % This is never going to happen in normal use. 
    obj.detachRecipeListeners;
    if ~doResume
        % Just load as normal
        success = obj.model.attachRecipe(fullPath);
    else
        % Resumption is slow at first so indicate to the user that stuff is happening

        % Attempt to resume the acquisition 
        % First we set the tile size in the GUI to what is in the recipe. 
        thisRecipe=BakingTray.settings.readRecipe(fullPath);
        obj.recipeEntryBoxes.other{1}.Value=thisRecipe.StitchingParameters.scannerSettingsIndex;
        obj.updateStatusText
        
        % Now we do the resumption
        [success,msg] = obj.model.resumeAcquisition(fullPath);
        if ~isempty(msg)
            msg = [sprintf('Scan settings not set correctly!\n'), msg];
            msg = [msg, sprintf('\nCORRECT THESE MANUALLY BEFORE CARRYING ON!')];
            warndlg(msg)
        end
    end

    if success
        % The following will run even if the scanner settings did not
        % set correctly. 
        obj.connectRecipeListeners
        obj.updateAllRecipeEditBoxesAndStatusText
        obj.updateRecipeFname

        %If the prepare GUI is open, we force an update
        if ~isempty(obj.view_prepare) && isvalid(obj.view_prepare)
            obj.view_prepare.updateCuttingConfigurationText
        end

        % Open the acquisition view
        if doResume
            obj.startPreviewSampleGUI
        end
    end
end %loadRecipe
