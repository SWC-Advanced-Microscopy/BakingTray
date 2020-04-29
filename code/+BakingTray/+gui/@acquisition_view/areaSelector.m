function areaSelector(obj,~,~)

    h = imrect(obj.imageAxes);
    rect_pos = wait(h);
    delete(h)
    [rectBottomLeft,MMpix] = obj.model.convertImageCoordsToStagePosition(rect_pos(1:2));

    frontPos = rectBottomLeft(2);
    leftPos  = rectBottomLeft(1) + MMpix*rect_pos(4);

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