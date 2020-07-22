function updateSectionImage(obj,~,~)
    % This callback function updates when the listener on obj.previewImageData fires or if the user 
    % updates the popup boxes for depth or channel
    if obj.verbose, fprintf('In acquisition_view.updateSectionImage callback\n'), end


    %TODO: Temporarily do not update section imaging if ribbon scanning
    if strcmp(obj.model.recipe.mosaic.scanmode,'ribbon')
        return
    end

    if ~obj.doSectionImageUpdate
        return
    end



    %Raise a console warning if it looks like the image has grown in size
    %TODO: this check can be removed eventually, once we're sure this does not happen ever.
    if numel(obj.sectionImage.CData) < numel(squeeze(obj.previewImageData(:,:,obj.depthToShow, obj.chanToShow)))
        fprintf('The preview image data in the acquisition GUI grew in size from %d x %d to %d x %d\n', ...
            size(obj.sectionImage.CData,1), size(obj.sectionImage.CData,2), ...
            size(obj.previewImageData,1), size(obj.previewImageData,2) )
    end

    if obj.rotateSectionImage90degrees
        obj.sectionImage.CData = rot90(squeeze(obj.previewImageData(:,:,obj.depthToShow, obj.chanToShow)));
    else
        obj.sectionImage.CData = squeeze(obj.previewImageData(:,:,obj.depthToShow, obj.chanToShow));
    end
    
end %updateSectionImage