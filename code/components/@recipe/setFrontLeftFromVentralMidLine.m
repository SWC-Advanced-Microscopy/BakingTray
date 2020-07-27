function setFrontLeftFromVentralMidLine(obj)
    % recipe.setFrontLeftFromVentralMidline
    %
    % Calculates the front-left position of sample based on the ventral mid-line.
    % The idea is that the user exposes the cerebellum until the pons is visible.
    % Then places the laser on the edge of the pons at the mid-line. If the brain
    % is straight then we can calculate the front left position given that the 
    % number of tiles in X and Y are set correctly. 
    %
    % This method sets the recipe.FrontLeft .X and .Y values. It doesn't move the stage.

    if isempty(obj.parent)
        fprintf('ERROR in setFrontLeftFromVentralMidLine: recipe class has nothing bound to property "parent". Can not access BT.\n')
        return
    end

    % We just need a tile pattern and don't want to generate an out of bounds error due to a funny
    % front/left position. So we pass "quiet" and "returnEvenIfOutOfBounds" to the tilePattern method
    tp=obj.tilePattern(true,true);

    if isempty(tp)
        fprintf('ERROR in setFrontLeftFromVentralMidLine: tile position data are empty. Likely an invalid setting. Can not proceed.\n')
        return
    end

    sizeOfSample=range(tp);
    [x,y]=obj.parent.getXYpos;

    left = x+sizeOfSample(1);
    front = y+sizeOfSample(2)/2;

    obj.FrontLeft.X=left;
    obj.FrontLeft.Y=front;
end % setFrontLeftFromVentralMidLine
