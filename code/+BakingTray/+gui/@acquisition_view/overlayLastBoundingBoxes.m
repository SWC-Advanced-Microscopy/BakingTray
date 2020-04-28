function overlayLastBoundingBoxes(obj)
    % Overlay the last obtained auto-boxes

    obj.removeOverlays
    stats = obj.model.autoROI.stats.roiStats(end);
    H=obj.overlayBoundingBoxesOnImage(stats.BoundingBoxes);
    obj.plotOverlayHandles.lastBoundingBoxes = H;
end %overlayLastBoundingBoxes