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
    obj.addBlankImageToImageAxes;


    if size(obj.model.lastPreviewImageStack,3)>1
        %A bit nasty but temporarily wipe the higher depths (they'll be re-made later)
        obj.model.lastPreviewImageStack(:,:,2:end,:)=[];
    end

    obj.updateImageLUT;

    % Remove all overlays. We will return the frosted area at the end if the user asked for
    % this because the box is ticked. 
    obj.removeOverlays


    % Ensure the section image is displayed
    obj.sectionImage.Visible='On';


    % Take the preview scan updating the preview image on each tile
    origupdatePreviewEveryNTiles = obj.updatePreviewEveryNTiles;
    try
        obj.updatePreviewEveryNTiles=2;
        obj.model.takeRapidPreview
    catch ME
        fprintf('BT.takeRapidPreview failed with error message:\n%s\n',ME.message)
        obj.updatePreviewEveryNTiles = origupdatePreviewEveryNTiles;
        for ii=1:length(ME.stack)
            disp(ME.stack(ii))
        end

        obj.overlayThreshBorderOnImage
        if obj.checkBoxShowSlide.Value == 1
            obj.overlaySlideFrostedAreaOnImage
        end
    end

    % Return to default
    obj.updatePreviewEveryNTiles = origupdatePreviewEveryNTiles;

    %Ensure the bakeStop button is enabled if BT.takeRapidPreview failed to run
    obj.button_BakeStop.Enable='on'; 
    obj.depthSelectPopup.Enable=depthEnableState; %return to original state

    % Run auto-ROI stuff (the following only runs if the recipe says we are in auto-ROI mode)
    obj.overlayThreshBorderOnImage


    if obj.checkBoxShowSlide.Value == 1
        obj.overlaySlideFrostedAreaOnImage
    end

end %startPreviewScan
