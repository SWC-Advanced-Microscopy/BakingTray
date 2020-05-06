function updateSectionImage(obj,~,~)
    % This callback function updates when the listener on obj.model.lastPreviewImageStack fires or if the user 
    % updates the popup boxes for depth or channel

    if obj.verbose
        fprintf('In acquisition_view.updateSectionImage callback\n')
    end

    % Possibly excessive checks to avoid any possibility of triggering update when it should not be.
    if ~obj.doSectionImageUpdate || obj.model.processLastFrames==false || obj.model.acquisitionInProgress == false
        return
    end


    %Only update the section image every so often to avoid slowing down the acquisition
    n=obj.model.currentTilePosition;
    if n==1 || mod(n,obj.updatePreviewEveryNTiles)==0 || n>=length(obj.model.positionArray)
        %Raise a console warning if it looks like the image has grown in size
        %TODO: this check can be removed eventually, once we're sure this does not happen ever.
        if numel(obj.sectionImage.CData) < numel(squeeze(obj.model.lastPreviewImageStack(:,:,obj.depthToShow, obj.chanToShow)))
            fprintf('The preview image data in the acquisition GUI grew in size from %d x %d to %d x %d\n', ...
                size(obj.sectionImage.CData,1), size(obj.sectionImage.CData,2), ...
                size(obj.model.lastPreviewImageStack,1), size(obj.model.lastPreviewImageStack,2) )
        end

        obj.sectionImage.CData = squeeze(obj.model.lastPreviewImageStack(:,:,obj.depthToShow, obj.chanToShow));

        %TODO: temporarily allow re-sizing of the image. Once autoROI bugs are ironed out we will either remove this or 
        % come up with a different solution
        if obj.verbose
            fprintf('Updating section image...\n')
        end


        % TODO -- check if the following is really needed or the correct way to go about things
        obj.imageAxes.YLim=[0,size(obj.sectionImage.CData,1)];
        obj.imageAxes.XLim=[0,size(obj.sectionImage.CData,2)];

        %
%%        fprintf('--> updateSectionImage doing horrible axis limit hack: XLim=[%d,%d] , YLim=[%d,%d]\n', ...
 %%           round(obj.imageAxes.XLim), round(obj.imageAxes.YLim))

        drawnow
    end




end %updateSectionImage