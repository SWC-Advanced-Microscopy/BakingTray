function overlayLastBoundingBoxes(obj)
    % Overlay the last obtained auto-boxes
    % TODO - tidy this and doc it
    obj.removeOverlays('lastBoundingBoxes')
    stats = obj.model.autoROI.stats.roiStats(end);
    H=obj.overlayBoundingBoxesOnImage(stats.BoundingBoxes);
    obj.plotOverlayHandles.lastBoundingBoxes = H;
end %overlayLastBoundingBoxes