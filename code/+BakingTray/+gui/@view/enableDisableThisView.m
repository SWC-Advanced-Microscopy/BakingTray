function enableDisableThisView(obj,enableState)
    % enableDisableThisView
    %
    % Purpose
    % Toggles the enable/disable state on all buttons and edit boxes. 
    % This method is called by the acquire GUI to ensure that whilst
    % it is open it is not possible to modify the recipe.
    %
    % Examples
    % bakingtray.gui.view.enableDisableThisView('on')
    % bakingtray.gui.view.enableDisableThisView('off')

    if nargin<2 && ~strcmp(enableState,'on') && ~strcmp(enableState,'off')
        return
    end

    entryBoxFields=fields(obj.recipeEntryBoxes);

    for ii=1:length(entryBoxFields)
        if isstruct( obj.recipeEntryBoxes.(entryBoxFields{ii}) ) 
            theseFields=fields(obj.recipeEntryBoxes.(entryBoxFields{ii}));
            for kk=1:length(theseFields)
                obj.recipeEntryBoxes.(entryBoxFields{ii}).(theseFields{kk}).Enable=enableState;
            end
        elseif iscell( obj.recipeEntryBoxes.(entryBoxFields{ii}) ) 
            for kk=1:length(obj.recipeEntryBoxes.(entryBoxFields{ii}))
                obj.recipeEntryBoxes.(entryBoxFields{ii}){kk}.Enable=enableState;
            end
        end
    end
    %The laser button should always be enabled
    obj.button_chooseDir.Enable=enableState;
    obj.button_recipe.Enable=enableState;
    obj.button_prepare.Enable=enableState;
    obj.button_start.Enable=enableState;
end %enableDisableThisView
