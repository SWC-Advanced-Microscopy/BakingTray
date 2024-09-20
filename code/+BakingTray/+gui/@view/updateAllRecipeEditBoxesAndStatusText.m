function updateAllRecipeEditBoxesAndStatusText(obj,~,~)
    % Update all recipe edit boxes if any recipe property is altered
    %
    % function BakingTray.gui.view.updateAllRecipeEditBoxesAndStatusText
    %
    %If any recipe property is updated in model.recipe we update all the edit boxes
    %and any relevant GUI elements. We also modify elements in other attached GUIs
    %if this is needed


    if ~obj.model.isRecipeConnected
        return
    end

    R=obj.model.recipe;

    for ii=1:length(obj.recipePropertyNames)
        thisProp = strsplit(obj.recipePropertyNames{ii},'||');

        % Certain recipe fields need unusual things done, so we handle those first in the following if statement.
        % This mirrors code in the method populateRecipePanel

        if strcmp(thisProp{2},'sampleSize')
            obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'X']).String = R.(thisProp{1}).(thisProp{2}).X;
            obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'Y']).String = R.(thisProp{1}).(thisProp{2}).Y;
        elseif strcmp(thisProp{2},'scanmode')
            % Find the index of the cell array in the popup which matches the current scan mode
            ind = strmatch(R.(thisProp{1}).(thisProp{2}), obj.recipeEntryBoxes.(thisProp{1}).(thisProp{2}).String);
            obj.recipeEntryBoxes.(thisProp{1}).(thisProp{2}).Value = ind;
        else
            obj.recipeEntryBoxes.(thisProp{1}).(thisProp{2}).String = R.(thisProp{1}).(thisProp{2});
        end
    end
    obj.updateStatusText

    %Now update the prepare GUI if this is present: cutting speed and thickness labels should be
    %green if they match those in the recipe
    if ~isempty(obj.view_prepare) && isvalid(obj.view_prepare)
        obj.view_prepare.checkSliceThicknessEditBoxValue
        obj.view_prepare.checkCuttingSpeedEditBoxValue
    end

end %updateAllRecipeEditBoxesAndStatusText
