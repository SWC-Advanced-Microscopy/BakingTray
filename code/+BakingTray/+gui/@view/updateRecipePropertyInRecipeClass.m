function updateRecipePropertyInRecipeClass(obj,eventData,~)
    %Replace a property in obj.model.recipe with the value the user just changed

    %Keeps strings as strings but converts numbers
    newValue=str2double(eventData.String);
    if isnan(newValue)
        newValue=eventData.String;
    end

    %Where to put this?
    propertyPath = strsplit(eventData.Tag,'||');

    if length(propertyPath)==2
        obj.model.recipe.(propertyPath{1}).(propertyPath{2})=newValue;
    elseif length(propertyPath)==3
        obj.model.recipe.(propertyPath{1}).(propertyPath{2}).(propertyPath{3})=newValue;
    else
        fprintf('ERROR IN BakingTray.gui.view.updateRecipePropertyInRecipeClass: property path is not 2 or 3\nCan not set recipe property!\n')
        return
    end

    if strcmp(propertyPath{2},'numOpticalPlanes') || strcmp(propertyPath{2},'sliceThickness')
        % If the number of planes were changed, we update the z-stack settings in the scanner software. 
        obj.model.scanner.applyZstackSettingsFromRecipe;
    end

end %updateRecipePropertyInRecipeClass
