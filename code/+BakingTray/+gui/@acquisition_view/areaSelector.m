function areaSelector(obj,~,~)
    % Draw a box on the preview image and use this as a basis for a ROI
    %
    % The box is scaled to the nearest whole tile. 

    % Disable draw box button so a second box can't be drawn
    obj.button_drawBox.Enable='off';
    obj.removeOverlays('NextROI')

    % Draw box and get coords
    imSize = size(obj.model.lastPreviewImageStack);
    imSize = imSize(1:2);
    defaultPos = [1,1,imSize(2), imSize(1)];
    roi = images.roi.Rectangle(obj.imageAxes,'Position',defaultPos);
    roi.Label='Adjust then double-click';

    % The only way I can find to move the label to the centre
    roi.RotationAngle=1E-10;

    % Reset zoom to zero then zoom out one step. Zooming out is needed
    % for the box to be useful. Only zoom out if we aren't already zoomed out.
    if obj.imageAxes.YLim(1)>=0 && obj.imageAxes.XLim(1)>=0
        obj.imageZoomHandler(struct('Tag','zerozoom')) %In case we are zoomed in
        obj.imageZoomHandler(struct('Tag','zoomout'))
    end



    % Place tile width and overlap proportion into the roi object
    dsMixPix = obj.model.downsampleMicronsPerPixel;
    stepSize.Xmics = (obj.model.recipe.TileStepSize.X * 1000) / dsMixPix;
    stepSize.Ymics = (obj.model.recipe.TileStepSize.Y * 1000) / dsMixPix;
    roi.UserData.stepSize = stepSize;
    roi.UserData.overlap = obj.model.recipe.mosaic.overlapProportion;


    M=addlistener(roi,'MovingROI',@snapToTiles);
    L=addlistener(roi,'ROIClicked',@clickCallback);

    uiwait;

    rect_pos = (roi.Position);
    delete(M)
    delete(L)
    delete(roi)



    [rectBottomLeft,MMpix] = obj.model.convertImageCoordsToStagePosition(rect_pos(1:2));

    frontPos = rectBottomLeft(2);
    leftPos  = rectBottomLeft(1);

    extentAlongX = round(rect_pos(4)*MMpix,2);
    extentAlongY = round(rect_pos(3)*MMpix,2);

    detailedMessage=false;

    if detailedMessage
        msg = sprintf(['Proceed with the following changes?\n', ...
            'Set the front/left position changes:\n', ...
             'X= %0.2f mm -> %0.2f\nY= %0.2f mm -> %0.2f mm\n', ...
            'The imaging area will change from from:\n', ...
            'X= %0.2f mm -> %0.2f mm\nY= %0.2f mm -> %0.2f mm'], ...
            obj.model.recipe.FrontLeft.X, leftPos, ...
            obj.model.recipe.FrontLeft.Y, frontPos, ...
            obj.model.recipe.mosaic.sampleSize.X, extentAlongX, ...
            obj.model.recipe.mosaic.sampleSize.Y, extentAlongY);
    else
        msg = 'Apply new selection box?';
    end

    A=questdlg(msg);

    if strcmpi(A,'yes')
        obj.model.recipe.FrontLeft.X = leftPos;
        obj.model.recipe.FrontLeft.Y = frontPos;
        obj.model.recipe.mosaic.sampleSize.X = extentAlongX;
        obj.model.recipe.mosaic.sampleSize.Y = extentAlongY;


        % Remove any old threshold borders from the image as these
        % confuse users.
        obj.removeOverlays('overlayThreshBorderOnImage'); %see obj.overlayThreshBorderOnImage
        
        % Overlay a box indicating the area we will image next time
        x = [leftPos,leftPos-extentAlongX, leftPos-extentAlongX, leftPos, leftPos];
        y = [frontPos, frontPos, frontPos-extentAlongY, frontPos-extentAlongY, frontPos];
        pixPos=obj.model.convertStagePositionToImageCoords([x(:),y(:)]);
        hold(obj.imageAxes,'on');
        obj.plotOverlayHandles.NextROI = plot(pixPos(:,1),pixPos(:,2),':', 'color',[0.2,0.3,1],'LineWidth',2,'Parent',obj.imageAxes);
        hold(obj.imageAxes,'off');
    end
    
    obj.button_drawBox.Enable='on';

end % areaSelector



function snapToTiles(src,~)
    % Snap to the nearest whole tile size
    pos=src.Position;

    stepSize = src.UserData.stepSize;
    overlap = src.UserData.overlap;

    % Round to nearest number of steps and then 
    % return ROI to the original central position
    if pos(3)<stepSize.Ymics
        pos(3)=stepSize.Ymics * (1+overlap);
    else
        pos(3) = round(pos(3)/stepSize.Ymics) * stepSize.Ymics + overlap*stepSize.Ymics;
    end
    if pos(4)<stepSize.Xmics
        pos(4)=stepSize.Xmics * (1+overlap);
    else
        pos(4) = round(pos(4)/stepSize.Xmics) * stepSize.Xmics + overlap*stepSize.Xmics;
    end


    % Set ROI size
    src.Position = pos;

    % Update ROI label
    labTxt = sprintf('%d by %d tiles', ...
            floor(pos(4)/stepSize.Ymics), ...
            floor(pos(3)/stepSize.Xmics));
    src.Label = labTxt;
end

function clickCallback(~,evt)
    % Returns control to the user if they double-click on the ROI
    if strcmp(evt.SelectionType,'double')
        uiresume;
    end
end
