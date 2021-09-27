function bake_callback(obj,~,~)
    % This callback runs when the bake button is pressed

    if obj.verbose
        fprintf('In acquisition_view.bake callback\n')
    end

    obj.updateStatusText



    [acqPossible, msg]=obj.model.checkIfAcquisitionIsPossible(true);
    if ~acqPossible
        obj.model.messageString = msg;
        return
    end

    %TODO -- Check whether it's safe to begin
    if obj.parentView.updateTileSizeLabelText == false
        startMsg = sprintf(['    ** WARNING **\nChosen resolution in BakingTray does not match that in ScanImage.\n',...
                            'If this is a mistake, reselect the "Tile Size" setting in BakingTray to correct the error.\n', ...
                            'Do you wish to Bake with the current settings?']);
    else
        startMsg = 'Are you sure you want to Bake this sample?';
    end

    % Allow the user to confirm they want to bake
    ohYes='Yes!';
    noWay= 'No way';
    choice = questdlg(startMsg, '', ohYes, noWay, noWay);

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
    obj.addBlankImageToImageAxes;
    obj.removeOverlays('overlaySlideFrostedAreaOnImage') % If the slide overlay was present we remove it

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
        sectionInd = obj.model.bake; %if the bake loop didn't start, it returns 0
    catch ME
        fprintf('\nBAKE FAILED IN acquisition_view. CAUGHT THE FOLLOWING ERROR:\n %s\n', ME.message)
        for ii=1:length(ME.stack)
            fprintf('Line %d in %s\n', ...
                ME.stack(ii).line, ME.stack(ii).file)
        end
        fprintf('\n')
        rethrow(ME)
        return
    end



    obj.button_BakeStop.Enable='on'; 

    % Enable the z-jack again if the prep GUI is open
    if isvalid(obj.parentView.view_prepare)
        obj.parentView.view_prepare.unLockZ;
    end


    if obj.checkBoxLaserOff.Value==1 & sectionInd>0
        % If the laser was slated to turn off then we also close
        % the acquisition GUI. This is because a lot of silly bugs
        % seem to crop up after an acquisition but they go away if
        % the user closes and re-opens the window. 
        obj.delete
    end

end %bake_callback
