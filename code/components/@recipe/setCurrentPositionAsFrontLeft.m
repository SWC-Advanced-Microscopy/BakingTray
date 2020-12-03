function setCurrentPositionAsFrontLeft(obj)
    % recipe.setCurrentPositionAsFrontLeft
    %
    % Store the current position as the front/left of the tile grid

    if isempty(obj.parent)
        fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
        return
    end
    hBT=obj.parent;
    [x,y]=hBT.getXYpos;
    obj.FrontLeft.X = x;
    obj.FrontLeft.Y = y;
end % setCurrentPositionAsFrontLeft
