function newSample(obj,~,~)
    % Loads the default recipe. 
    % In future could spawn a wizard
    
    obj.loadRecipe([],[],fullfile(BakingTray.settings.settingsLocation,'default_recipe.yml'))
    
    % Resonant scanner is turned on if necessary. This gives it the most time possible to warm up
    obj.model.scanner.leaveResonantScannerOn

    % Set to default values other properties of BakingTray
    obj.model.currentSectionNumber = 1;

end %newSample