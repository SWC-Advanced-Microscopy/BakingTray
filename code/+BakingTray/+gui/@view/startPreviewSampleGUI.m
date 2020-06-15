function startPreviewSampleGUI(obj,~,~)
    % Start the preview sample GUI

    if isempty(obj.view_prepare)
        % The user must be resuming since they never prepared anything
        warndlg('You seem to be resuming an acquisition. Please first open the Prepare Sample window and confirm the settings look correct','');
        return
    end

    % Raise a warning if it appears the user prepared the sample with cutting parameters
    % different from those the imaging acquisition will use. This scenario can lead
    % to the brain surface moving away from where it currently is. 
    lastThickness=obj.model.recipe.lastSliceThickness;
    warnMsg='';
    if ~isempty(lastThickness)
        if lastThickness~=obj.model.recipe.mosaic.sliceThickness
            warnMsg=[warnMsg,sprintf('You will be cutting %0.2f sections but you seem to have prepared the sample at %0.2f.\n',...
                obj.model.recipe.mosaic.sliceThickness, lastThickness)];
            fprintf(warnMsg)
        end
    end

    lastCutSpeed=obj.model.recipe.lastCuttingSpeed;
    if ~isempty(lastCutSpeed)
        if lastCutSpeed~=obj.model.recipe.mosaic.cuttingSpeed
            warnMsg=[warnMsg,sprintf('You will be cutting at %0.2f mm/s but you seem to have prepared the sample at %0.2f mms/s.\n',...
                obj.model.recipe.mosaic.cuttingSpeed, lastCutSpeed)];
            fprintf(warnMsg)
        end
    end

    %The confirmation dialog will incorporate messages from the above two warning scenarios if they are present. 
    %Final start comes in the next GUI
    if ~isempty(warnMsg)
        choice = questdlg([warnMsg,'Are you sure you want to start acquisition?'], '', 'Yes', 'No', 'No');
        switch choice
            case 'No'
                return
            case 'Yes'
        end
    end

    %Open an acquisition view if it's not already been opened
    if isempty(obj.view_acquire) || ~isvalid(obj.view_acquire)
        obj.view_acquire=BakingTray.gui.acquisition_view(obj.model,obj);
    else
        %otherwise raise it (TODO: currently not possible since button is disabled when acq GUI starts)
        figure(obj.view_acquire.hFig)
    end
end %startPreviewSampleGUI
