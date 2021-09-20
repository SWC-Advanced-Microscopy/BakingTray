function takeOneSlice(obj,~,~)
    %Take a single slice off the block
    %
    % function BT.takeOneSlice(obj,~,~)
    %
    %

    if obj.model.allStagesReferenced == false
            obj.parentView.referenceStages;
            return
    end

    [cuttingPossible,msg]=obj.model.checkIfCuttingIsPossible;
    if ~cuttingPossible
        warndlg(msg,'')
        return
    end

    obj.resetBladeIfNeeded

    obj.model.sliceSample(obj.lastSliceThickness, obj.lastCuttingSpeed);
end
