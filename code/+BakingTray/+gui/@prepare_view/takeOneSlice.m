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
    obj.model.yAxis.absoluteMove(0); % So we are centred
    obj.model.sliceSample(obj.lastSliceThickness, obj.lastCuttingSpeed);
end
