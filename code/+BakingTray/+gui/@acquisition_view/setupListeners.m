function setupListeners(obj)
    %Add some listeners to monitor properties on the scanner component
    obj.listeners{1}=addlistener(obj.model, 'currentTilePosition', 'PostSet', @obj.placeNewTilesInPreviewData);

    obj.listeners{end+1}=addlistener(obj.model.scanner, 'acquisitionPaused', 'PostSet', @obj.updatePauseButtonState);
    obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.updatePauseButtonState);
    obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.updatePauseButtonState);

    obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.updateBakeButtonState);
    obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.updateBakeButtonState);

    obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.disable_ZoomElementsDuringAcq);
    obj.listeners{end+1}=addlistener(obj.model, 'abortAfterSectionComplete', 'PostSet', @obj.updateBakeButtonState);


    % The channels that can be displayed are updated with these two listeners
    obj.listeners{end+1}=addlistener(obj.model.scanner,'channelsToSave', 'PostSet', @obj.updateChannelsPopup);
    obj.listeners{end+1}=addlistener(obj.model.scanner,'scanSettingsChanged', 'PostSet', @obj.updateChannelsPopup);

    obj.listeners{end+1}=addlistener(obj.model.scanner, 'channelLookUpTablesChanged', 'PostSet', @obj.updateImageLUT);
    obj.listeners{end+1}=addlistener(obj.model.scanner, 'isScannerAcquiring', 'PostSet', @obj.updateBakeButtonState);
    obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.indicateCutting);

    obj.listeners{end+1}=addlistener(obj.model.recipe, 'mosaic', 'PostSet', @obj.populateDepthPopup);

    % Update checkboxes
    obj.listeners{end+1}=addlistener(obj.model, 'leaveLaserOn', 'PostSet', @(~,~) set(obj.checkBoxLaserOff,'Value',~obj.model.leaveLaserOn) );
    obj.listeners{end+1}=addlistener(obj.model, 'sliceLastSection', 'PostSet', @(~,~) set(obj.checkBoxCutLast,'Value',obj.model.sliceLastSection) );
end %close setupListeners