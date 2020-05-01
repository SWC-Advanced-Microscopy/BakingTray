function getThreshold(obj)
    % Get threshold from current preveiw image
    % EARLY TEST
    % TODO -- tidy and doc it
    %
    % Rob Campbell - SWC, April 2020
    %

    if isempty(obj.lastPreviewImageStack)
        return
    end

    obj.autoROI.previewImages=obj.returnPreviewStructure;

    % Do not proceed if the image seems empty
    if all( obj.autoROI.previewImages.imStack(:) == mode(obj.autoROI.previewImages.imStack(:)) )
        fprintf('BT.%s finds an empty preview image. Not running threshold algorithm\n', ...
            mfilename)
        return
    end
    threshSD = autoROI.autothresh.run(obj.autoROI.previewImages);

    obj.autoROI.stats=autoROI(obj.autoROI.previewImages,'tThreshSD',threshSD,'doPlot',false);

end % getThreshold