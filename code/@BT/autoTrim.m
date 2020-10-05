function autoTrim(obj)
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

    % TODO -- temporary until we add a button to the GUI
    % See also line 44 in prepare_view
    W = evalin('base','whos');
    if ismember('hBTview',{W.name})
        hBTv = evalin('base','hBTview');
    end

    if isvalid(hBTv.view_prepare)
        hBTv.view_prepare.editBox.cuttingSpeed.String = num2str(obj.recipe.mosaic.cuttingSpeed);
        hBTv.view_prepare.lastCuttingSpeed = obj.recipe.mosaic.cuttingSpeed; % TODO -- do we need a second last thickness?? Seems like a pointless idea. 
        hBTv.view_prepare.checkCuttingSpeedEditBoxValue
    end

    for tCut=cutSeq

        if isvalid(hBTv.view_prepare)
            hBTv.view_prepare.editBox.sliceThickness.String = num2str(tCut);
            hBTv.view_prepare.lastSliceThickness = tCut;
            hBTv.view_prepare.checkSliceThicknessEditBoxValue
        end

        success = obj.sliceSample(tCut);
        if ~success
            return
        end
    end

end




