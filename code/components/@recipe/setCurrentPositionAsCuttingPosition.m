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
    obj.CuttingStartPoint.Y = 0; % By default force cutting to be centred on blade
end % setCurrentPositionAsCuttingPosition
