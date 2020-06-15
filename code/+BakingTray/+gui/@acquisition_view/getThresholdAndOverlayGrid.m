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

    if ~isfield(obj.model.autoROI,'stats')
        return
    end

    % Obtain the threshold between sample and background. This populates
    % data in obj.model.autoROI.stats
    obj.model.getThreshold;

    % Use the data generated above to calculate a tile pattern for imaging
    % this sample
    z=obj.model.recipe.tilePattern(false,false,obj.model.autoROI.stats.roiStats.BoundingBoxDetails);

    % Overlay this tile pattern onto the preview image
    obj.overlayTileGridOnImage(z)
end
