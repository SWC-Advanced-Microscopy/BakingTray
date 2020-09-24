function finished = autoTrim(obj)
    % Trims the block to reach the cutting thickness from the last slice thickness

    cutSeq = obj.genAutoTrimSequence();
    if isempty(cutSeq)
        return
    end

    for tCut=cutSeq
        success = obj.sliceSample(tCut);
        if ~success
            return
        end
    end

end
