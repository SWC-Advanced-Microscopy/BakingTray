function updateAllRecipeEditBoxesAndStatusText(obj,~,~)
    %If any recipe property is updated in model.recipe we update all the edit boxes
    %and any relevant GUI elements. We also modify elements in other attached GUIs
    %if this is needed
    if ~obj.model.isRecipeConnected
        return
    end

    R=obj.model.recipe;

    for ii=1:length(obj.recipePropertyNames)
        thisProp = strsplit(obj.recipePropertyNames{ii},'||');
        if ~strcmp(thisProp{2},'sampleSize')
            obj.recipeEntryBoxes.(thisProp{1}).(thisProp{2}).String = R.(thisProp{1}).(thisProp{2});
        elseif strcmp(thisProp{2},'sampleSize')
            obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'X']).String = R.(thisProp{1}).(thisProp{2}).X;
            obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'Y']).String = R.(thisProp{1}).(thisProp{2}).Y;
        end
    end
    obj.updateStatusText

    %Now update the prepare GUI if this is present: cutting speed and thickness labels should be
    %green if they match those in the recipe
    if ~isempty(obj.view_prepare) && isvalid(obj.view_prepare)
        obj.view_prepare.checkSliceThicknessEditBoxValue
        obj.view_prepare.checkCuttingSpeedEditBoxValue
    end

    %Set the current section number to be equal to the start number
    %TODO: this may be creating a problem. I notice that the current section number is not updating 
    %      and is stuck at 1. This might be why.
    % obj.model.currentSectionNumber=obj.model.recipe.mosaic.sectionStartNum;

end %updateAllRecipeEditBoxesAndStatusText
