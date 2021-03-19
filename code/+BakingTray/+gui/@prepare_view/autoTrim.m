function autoTrim(obj,~,~)
    % Automatically slice down to the required slice thicknes for imaging
    %
    % function autoTrim(obj,~,~)
    %
    % Purpose
    % runs BT.autoTrim to automatically achieve the correct cutting thickness for imaging


    %% TODO remove the TODO hack in prepare_view.m

    % Allow use the choice whether to proceed
    cutSeq=obj.model.genAutoTrimSequence;
    if isempty(cutSeq)
        return
    end

    str = sprintf('Cut down to %d \\mum sections over %d slices totalling %0.1f mm?\n', ...
        round(cutSeq(end)*1000), length(cutSeq), sum(cutSeq));
    OUT=questdlg(str,'','Yes','No',struct('Default','No','Interpreter','tex'));

    if strcmpi(OUT,'no') || isempty(OUT)
        return
    end

    % Set the cutting speed
    obj.editBox.cuttingSpeed.String = num2str(obj.model.recipe.mosaic.cuttingSpeed);
    obj.lastCuttingSpeed = obj.model.recipe.mosaic.cuttingSpeed;
    obj.checkCuttingSpeedEditBoxValue

    % Loop through all and cut
    wF = waitbar(0,'Preparing to cut');
    for n = 1:length(cutSeq)
        tCut = cutSeq(n);

        waitbar(n/length(cutSeq), wF, sprintf('Cutting %d micron section',round(tCut*1000)))


        obj.editBox.sliceThickness.String = num2str(tCut);
        obj.lastSliceThickness = tCut;
        obj.checkSliceThicknessEditBoxValue

        success = obj.model.sliceSample(tCut,obj.lastCuttingSpeed);
        if ~success
            close(wF)
            return
        end
    end

    close(wF)


end
