function setCurrentPositionAsCuttingPosition(obj)
    % recipe.setCurrentPositionAsCuttingPosition
    %
    % Store the current stage position as the position at which we will start cutting

    if isempty(obj.parent)
        fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
        return
    end
    hBT=obj.parent;
    [x,y]=hBT.getXYpos;
    obj.CuttingStartPoint.X = x;

    % The y position is not set by the user but comes from a settings file.
    % This is set in the recipe at load time in the constructor

    % Automatically set the cut size
    obj.autoSetCutSize
end % setCurrentPositionAsCuttingPosition
