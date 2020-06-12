function success=getThreshold(obj)
    % Get threshold from current preveiw image
    % 
    % Purpose
    % Runs autoROI.autothresh.run to get a threshold based on obj.autoROI.previewImages
    % Once done, populates  BT.autoROI.stats with the output of autoROI. This wipes
    % whatever was there before. 
    %
    % TODO -- tidy and doc it
    %
    % Rob Campbell - SWC, April 2020
    %
    
    success=false;
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

    % Obtain the threshold
    threshSD = autoROI.autothresh.run(obj.autoROI.previewImages);

    % Get stats
    obj.autoROI.stats=autoROI(obj.autoROI.previewImages,'tThreshSD',threshSD,'doPlot',false);
    obj.autoROI.stats.roiStats.sectionNumber=0; %Indicates that this is the initial preview

    success=true;
end % getThreshold