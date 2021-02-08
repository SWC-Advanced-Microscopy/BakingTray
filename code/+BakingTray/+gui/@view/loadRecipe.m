function loadRecipe(obj,~,~)
    % Loads a new recipe and initiates resumption of a previous acquisition if necessary

    % Load recipe button callback -- loads a new recipe from disk
    [fname,absPath] = uigetfile('*.yml','Choose a recipe',BakingTray.settings.settingsLocation);

    if fname==0
        % if the user hits cancel
        return
    end

    fullPath = fullfile(absPath,fname);

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
    end

    % Do nothing if the user presses cancel or closes the window
    if strcmpi(reply,'cancel') || isempty(reply)
        return
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
        % First we set the tile size in the GUI to what is in the recipe. The following is 
        % rather a hack. It would be better that each set of scan settings has a label
        % and then we set it to that label or index.
        thisRecipe=BakingTray.settings.readRecipe(fullPath);

        tileOptions = obj.recipeEntryBoxes.other{1}.UserData;
        pixLin = [tileOptions.pixelsPerLine];
        linFrm = [tileOptions.linesPerFrame];
        zmFact = [tileOptions.zoomFactor];

        % Find which line in the tile-size drop down this corresponds to 
        % TODO - this should be implemented in the scanner, I think.
        ind = (pixLin==thisRecipe.Tile.nColumns) .* ...
              (linFrm==thisRecipe.Tile.nRows) .* ...
              (zmFact==thisRecipe.ScannerSettings.zoomFactor); %TODO: this line is dangerous. Not all scanners will have this
        ind = find(ind);
        if ~isempty(ind) && length(ind)==1
            obj.recipeEntryBoxes.other{1}.Value=ind;
            obj.updateStatusText
        else
            fprintf(['Image settings do not match known values.\n', ...
                'Attempting to resume but not updating "Tile Size" in BakingTray GUI\n'])
        end

        % Now we do the resumption
        success = obj.model.resumeAcquisition(fullPath);
    end

    if success
        obj.connectRecipeListeners
        obj.updateAllRecipeEditBoxesAndStatusText
        obj.updateRecipeFname

        %If the prepare GUI is open, we force an update
        if ~isempty(obj.view_prepare)
            obj.view_prepare.updateCuttingConfigurationText
        end

        % Open the acquisition view
        if doResume
            obj.startPreviewSampleGUI
        end
    end
end %loadRecipe
