function bake_callback(obj,~,~)
    % Run when the bake button is pressed
    if obj.verbose
        fprintf('In acquisition_view.bake callback\n')
    end

    obj.updateStatusText
    %Check whether it's safe to begin
    [acqPossible, msg]=obj.model.checkIfAcquisitionIsPossible;
    if ~acqPossible
        if ~isempty(msg)
            warndlg(msg,'');
        end
       return
    end

    % Allow the user to confirm they want to bake
    ohYes='Yes!';
    noWay= 'No way';
    choice = questdlg('Are you sure you want to Bake this sample?', '', ohYes, noWay, noWay);

    switch choice
        case ohYes
            % pass
        case noWay
            return
        otherwise
            return
    end


    % Update the preview image in case the recipe has altered since the GUI was opened or
    % since the preview was last taken.
    obj.initialisePreviewImageData;
    obj.setUpImageAxes;


    % Force update of the depths and channels because for some reason they 
    % sometimes do not update when the recipe changes. 
    obj.populateDepthPopup
    obj.updateChannelsPopup

    obj.chooseChanToDisplay %By default display the channel shown in ScanImage

    set(obj.button_Pause, obj.buttonSettings_Pause.enabled{:})
    obj.button_BakeStop.Enable='off'; %This gets re-enabled when the scanner starts imaging

    obj.updateImageLUT;
    obj.model.leaveLaserOn=false; % TODO: For now always set the laser to switch off when starting [17/08/2017]
    try
        obj.model.bake;
    catch ME
        fprintf('\nBAKE FAILED IN acquisition_view. CAUGHT THE FOLLOWING ERROR:\n\t%s\n', ME.message)
        obj.button_BakeStop.Enable='on'; 
        return
    end
    
    if obj.checkBoxLaserOff.Value
        % If the laser was slated to turn off then we also close
        % the acquisition GUI. This is because a lot of silly bugs
        % seem to crop up after an acquisition but they go away if
        % the user closes and re-opens the window.
        obj.delete
    end

end %bake_callback