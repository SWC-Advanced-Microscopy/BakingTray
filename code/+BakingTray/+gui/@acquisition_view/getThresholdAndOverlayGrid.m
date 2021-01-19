function getThresholdAndOverlayGrid(obj,~,~)
    % Get auto-ROI threshold from a preview image then overlay tile grid
    %
    % Purpose
    % The first step in an auto-ROI acquisition is for the use to take a 
    % preview scan of the FOV. Then a threshold for sample/no sample is 
    % obtained. This can be used to obtain ROIs and from these a tile grid
    % is generated. This is then overlaid onto the preview image.
    %
    % Inputs
    % none -- this can be used as a callback function
    %
    % Outputs
    % none

    % Do not proceed if we are not in auto-ROI mode
    if ~strcmp(obj.model.recipe.mosaic.scanmode,'tiled: auto-ROI')
        return
    end

    % Obtain the section image and bail out if the image is empty
    im = obj.sectionImage.CData;
    if sum(im(:))==0
        return
    end

    % Obtain the threshold between sample and background. This populates
    % data in obj.model.autoROI.stats
    obj.model.getThreshold;

    % If no threshold was obtained for some reason, we bail out
    if ~isfield(obj.model.autoROI,'stats')
        return
    end

    % Draw border around the brain
    tBW=autoROI.binarizeImage(im, obj.model.downsampleMicronsPerPixel,obj.model.autoROI.stats.roiStats.tThresh);
    B=bwboundaries(tBW.afterExpansion,'noholes');
    hold(obj.imageAxes,'on')

    for ii=1:length(B)
        pixPos=obj.model.convertStagePositionToImageCoords((B{ii}));
                pixPos=((B{ii}));

        obj.plotOverlayHandles.brainBorder(ii) = plot(pixPos(:,2), pixPos(:,1),'g-','Parent',obj.imageAxes);
    end
    hold(obj.imageAxes,'off')

    % Use the data generated above to calculate a tile pattern for imaging
    % this sample
    z=obj.model.recipe.tilePattern(false,false,obj.model.autoROI.stats.roiStats.BoundingBoxDetails);

    % Overlay this tile pattern onto the preview image
    obj.overlayTileGridOnImage(z)
end
