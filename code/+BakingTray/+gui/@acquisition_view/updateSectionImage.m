function updateSectionImage(obj,~,~,forceUpdate)
    % This callback function updates when the listener on obj.model.lastPreviewImageStack 
    % (which is in BT) fires or if the user updates the popup boxes for depth or channel.


    if nargin<4
        forceUpdate=false;
    end

    if obj.verbose
        fprintf('In acquisition_view.updateSectionImage callback\n')
    end

    % Possibly excessive checks to avoid any possibility of triggering update when it should not be.
    if ~obj.doSectionImageUpdate || obj.model.processLastFrames==false || obj.model.acquisitionInProgress == false
        return
    end


    %Only update the section image every so often to avoid slowing down the acquisition
    n=obj.model.currentTilePosition;
    if n==1 || mod(n,obj.updatePreviewEveryNTiles)==0 || n>=length(obj.model.positionArray) || forceUpdate
        %Raise a console warning if it looks like the image has grown in size
        if numel(obj.sectionImage.CData) < numel(squeeze(obj.model.lastPreviewImageStack(:,:,obj.depthToShow, obj.chanToShow)))
            fprintf('The preview image data in the acquisition GUI grew in size from %d x %d to %d x %d\n', ...
                size(obj.sectionImage.CData,1), size(obj.sectionImage.CData,2), ...
                size(obj.model.lastPreviewImageStack,1), size(obj.model.lastPreviewImageStack,2) )
        end

        obj.sectionImage.CData = squeeze(obj.model.lastPreviewImageStack(:,:,obj.depthToShow, obj.chanToShow));

        if obj.verbose
            fprintf('Updating section image...\n')
        end


        % TODO -- Check if the following is really needed or the correct way to go about things.
        %         The difficulty is that as it stands it does not allow us the freedom to have larger
        %         axes during an autoROI in order to keep the image size the same thoughout. 
        obj.imageAxes.YLim=[0,size(obj.sectionImage.CData,1)];
        obj.imageAxes.XLim=[0,size(obj.sectionImage.CData,2)];

        drawnow
    end


end %updateSectionImage
