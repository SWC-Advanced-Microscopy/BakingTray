function toggleEnable(obj,toggleState)
    % Enables/disables all UI elements. This method is triggered by the callback prepare_view.updateGUIduringAcq so 
    % that it automatically disables the GUI during preview scans and bakes. 
    %
    % Inputs
    % toggleState - should be the string: 'on' or 'off' The function does nothing if this is not the case

    if ~ischar(toggleState)
        return
    end

    if ~strcmpi(toggleState,'on') && ~strcmpi(toggleState,'off')
        return
    end

    obj.stopMotion_button.Enable=toggleState;
    obj.takeSlice_button.Enable=toggleState;
    obj.takeNSlices_button.Enable=toggleState;
    obj.setCuttingPos_button.Enable=toggleState;
    obj.setFrontLeft_button.Enable=toggleState;
    obj.setVentralMidline_button.Enable=toggleState;
    obj.moveToSample_button.Enable=toggleState;
    obj.autoTrim_button.Enable=toggleState;


    jogButtons=fields(obj.largeStep);

    for ii=1:length(jogButtons)
        obj.largeStep.(jogButtons{ii}).Enable=toggleState;
        obj.smallStep.(jogButtons{ii}).Enable=toggleState;
    end

    editBoxes=fields(obj.editBox);
    for ii=1:length(editBoxes)
        obj.editBox.(editBoxes{ii}).Enable=toggleState;
    end

    obj.editBox.cut_Y.Enable='Off'; % At least for now, this is always disabled

    % Handle the timer for updating the view
    switch toggleState
        case 'on'
            start(obj.prepareViewUpdateTimer);
        case 'off'
            stop(obj.prepareViewUpdateTimer);
    end

    % Read the stage positions to force a GUI update of the positions, just in case
    obj.model.getXpos;
    obj.model.getYpos;
    obj.model.getZpos;

end %toggleEnable