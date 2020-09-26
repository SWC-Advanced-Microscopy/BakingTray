function finished = autoTrim(obj)
    % Trims the block to reach the cutting thickness from the last slice thickness
    %
    % hBT.autoTrim
    %
    % Purpose
    % Imaging cut thickness should be gradually approached from thicker sections. This
    % is to avoid the vibratome from alternately cutting thick and thin slices. This
    % cuts increasingly thinner slices before taking three slices the target slice 
    % thickness. The target slice thickness is obtained from the recipe. The cutting
    % speed is also taken from the recipe.


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
