function overlayThreshBorderOnImage(obj)
    % Overlay a line indicating the region of the preview image used for estimating the background
    %
    %
    % Purpose
    % The auto-ROI algorithm uses the edge of the image to estimate the median and SD of 
    % background (non-sample) pixels. In this area, therefore, we want no sample. To aid
    % the user, overlayThreshBorderOnImage plots a line around the perimeter of the imaged
    % area. There should be no sample in this zone. This method runs after the preview scan
    % but only plots the border if we are in auto-ROI mode. 
    %
    % Inputs
    % none
    %
    %
    %
    % See also:
    % obj.overlayTileGridOnImage
    % obj.overlayBoundingBoxesOnImage
    % obj.overlayPointsOnImage
    % obj.removeOverlays


    % Bail out if we are not in auto-ROI mode
    if ~strcmp(obj.model.recipe.mosaic.scanmode,'tiled: auto-ROI')
        return
    end

    % Obtain the section image size but bail out if the image is empty or if
    % there are no preview image data to work with
    im = obj.sectionImage.CData;
    if sum(im(:))==0
        return
    end

    % Set up
    hold(obj.imageAxes,'on')
    obj.removeOverlays(mfilename)

    % Get the width of the border region in pixels from the auto-ROI settings
    sAuto=autoROI.readSettings;
    b = sAuto.main.borderPixSize;
    % Scale by amount we resize by, as the border pixels are pulled out of a downsampled image
    b = b * (sAuto.stackStr.rescaleTo / obj.model.downsampleMicronsPerPixel);

    % Now plot the border area
    n=size(im,2);
    x=[b+1,n-b,n-b,b+1,b+1];
    n=size(im,1);
    y=[b+1,b+1,n-b,n-b,b+1];
    
    obj.plotOverlayHandles.(mfilename) = plot(x,y,'--g','Parent',obj.imageAxes);

    n=size(im,2);
    x=[1,n,n,1,1];
    n=size(im,1);
    y=[1,1,n,n,1];

    obj.plotOverlayHandles.(mfilename)(2) = plot(x,y,'--g','Parent',obj.imageAxes);

    set(obj.plotOverlayHandles.(mfilename),'LineWidth',2)

    hold(obj.imageAxes,'off')

    drawnow

end %overlayTileGridOnImage
