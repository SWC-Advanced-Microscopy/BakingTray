function startPreviewScan(obj,~,~)
    %Starts a rapd, one depth, preview scan. 

    %TODO: The warning dialog in case of failure to scan is created in BT.takeRapidPreview
    %       Ideally it should be here, to matach what happens elsewhere, but this is not 
    %       possible right now because we have to transiently change the sample ID to have
    %       the acquisition proceed if data already exist in the sample directory. Once this
    %       is fixed somehow the dialog creation will come here. 

    if obj.verbose
        fprintf('In acquisition_view.startPreviewScan callback\n')
    end

    %Disable depth selector since we have just one depth
    depthEnableState=obj.depthSelectPopup.Enable;
    obj.depthSelectPopup.Enable='off';
    obj.button_BakeStop.Enable='off'; %This gets re-enabled when the scanner starts imaging

    obj.chooseChanToDisplay %By default display the channel shown in ScanImage


    % Update the preview image in case the recipe has altered since the GUI was opened or
    % since the preview was last taken.
    obj.initialisePreviewImageData;
    obj.setUpImageAxes;

    if size(obj.previewImageData,3)>1
        %A bit nasty but temporarily wipe the higher depths (they'll be re-made later)
        obj.previewImageData(:,:,2:end,:)=[];
    end

    obj.updateImageLUT;

    try
        obj.model.takeRapidPreview
    catch ME
        fprintf('BT.takeRapidPreview failed with error message:\n%s\n',ME.message)
    end

    %Ensure the bakeStop button is enabled if BT.takeRapidPreview failed to run
    obj.button_BakeStop.Enable='on'; 
    obj.depthSelectPopup.Enable=depthEnableState; %return to original state

    % Copy data to the model (TODO: should we only keep it there?)
    obj.model.lastPreviewImageStack = obj.previewImageData;
end %startPreviewScan