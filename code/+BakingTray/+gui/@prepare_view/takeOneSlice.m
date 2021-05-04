function takeOneSlice(obj,~,~)
    %Take a single slice off the block
    %
    % function BT.takeOneSlice(obj,~,~)
    %
    %

    [cuttingPossible,msg]=obj.model.checkIfCuttingIsPossible;
    if ~cuttingPossible
        warndlg(msg,'')
        return
    end

    % Move to the cutting start point. This causes the blade to always
    % return to this position when trimming and it avoids user confusion
    % in cases such as an abort of the cutting that then leads to the blade
    % returning to a location above the sample
    obj.model.moveXYto(obj.model.recipe.CuttingStartPoint.X,0,true)

    obj.model.sliceSample(obj.lastSliceThickness, obj.lastCuttingSpeed);
end
