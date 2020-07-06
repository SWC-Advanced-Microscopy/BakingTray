function areaSelector(obj,~,~)
    % Draw a box on the preview image and use this as a basis for a ROI
    %
    % The box is scaled to the nearest whole tile. 


    % Draw box and get coords
    defaultPos = [5,5,floor(obj.imageAxes.XLim(2)-10), ...
                     floor(obj.imageAxes.YLim(2)-10)];
    roi = images.roi.Rectangle(obj.imageAxes,'Position',defaultPos);
    roi.Label='Adjust then double-click';

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
        fprintf('\nRECIPE UPDATED\n')
    end

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
            floor(pos(3)/stepSize.Xmics))
    src.Label = labTxt;
end

function clickCallback(~,evt)
    % Returns control to the user if they double-click on the ROI
    if strcmp(evt.SelectionType,'double')
        uiresume;
    end
end
