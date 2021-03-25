function newSample(obj,~,~)
    % Loads the default recipe. 
    % In future could spawn a wizard
    
    obj.loadRecipe([],[],fullfile(BakingTray.settings.settingsLocation,'default_recipe.yml'))
    obj.model.scanner.leaveResonantScannerOn
end %newSample