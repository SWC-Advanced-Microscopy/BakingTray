function overlayLastBoundingBoxes(obj)
    % Overlay the last obtained auto-boxes
    %
    % Purpose
    % Overlay the last obtained bounding boxes onto the current section image. 

    % NOTE: we can not just blindly overlay the last ROIs as these may 
    % have been calculated using different front/left coords. e.g. if we
    % determined the ROIs based on the preview image then acquired the next
    % section based on this, the F/L would have moved inwards almost cetrainly. 
    % So we need to shift ROIs accordingly. 

    overlayNonShifted=true;

    if overlayNonShifted
        % First we optionally overlay the vanilla borders before attempting to correct them
        Hv = obj.overlayBoundingBoxesOnImage(obj.model.autoROI.stats.roiStats(end).BoundingBoxes);
        set(Hv,'color', 'r', 'linestyle', '-', 'linewidth', 1)
    end


    % Turn the last acquired image into a preview structure. This gets the F/L with 
    % which is was acquired and keeps our working.
    pp=obj.model.returnPreviewStructure;
    L = autoROI.shiftROIsBasedOnStageFrontLeft(pp.frontLeftStageMM,obj.model.autoROI.stats.roiStats(end));

    obj.overlayBoundingBoxesOnImage(L.BoundingBoxes,false);

    drawnow
end %overlayLastBoundingBoxes
