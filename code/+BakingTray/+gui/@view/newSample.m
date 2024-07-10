function newSample(obj,~,~)
    % Loads the default recipe and resets various parameters in BakingTray.

    % Allow the user to confirm they want to proceed
    ohYes='Yes!';
    noWay= 'No way';
    choice = questdlg('Are you sure you want to start a new sample?', '', ohYes, noWay, noWay);

    switch choice
        case ohYes
            % pass
        case noWay
            return
        otherwise
            return
    end


    obj.loadRecipe([],[],fullfile(BakingTray.settings.settingsLocation,'default_recipe.yml'))

    % Resonant scanner is turned on if necessary. This gives it the most time possible to warm up
    obj.model.scanner.leaveResonantScannerOn

    % Set to default values other properties of BakingTray
    obj.model.currentSectionNumber = 1;

    % Set default jog sizes (redundant since we close the GUI but let's leave it here for now)
    if ~isempty(obj.view_prepare) && isvalid(obj.view_prepare)
        obj.view_prepare.resetStepSizesToDefaults;
    end

    % A bit of a horrible hack to re-set the pixel size
    obj.recipeEntryBoxes.other{1}.Value=1; % Sets the drop-down to entry 1
    obj.model.scanner.setImageSize(obj.recipeEntryBoxes.other{1}) % apply this to ScanImage


    % Wipe the sample save path
    obj.text_sampleDir.String='';
    obj.model.sampleSavePath='';

    % Close the prepare GUI to reset it. (Hack but it's OK)
    delete(obj.view_prepare)

end %newSample
