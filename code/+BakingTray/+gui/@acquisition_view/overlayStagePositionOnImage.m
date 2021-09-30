function overlayStagePositionOnImage(obj,xPos,yPos)
    % Overlay the position of the stage on the slide. 
    %
    %
    % Purpose
    % Overay a red box indicating where the imaging position is.
    %
    % Inputs
    % xPos - x position of stage in mm
    % yPos - y position of stage in mm
    %
    % See also:
    % obj.overlayBoundingBoxesOnImage
    % obj.overlayPointsOnImage
    % obj.removeOverlays
    % obj.overlaySlideFrostedAreaOnImage

    hold(obj.imageAxes,'on')

    obj.removeOverlays(mfilename)
    

    pixPos=obj.model.convertStagePositionToImageCoords([xPos,yPos]);


    % TODO: this needs to be based on absolute units or scaled by the number
    % of boxes. Otherwise it doesn't look nice. Ends up overlapping with the 
    % bounding box at larger box sizes.

    % Figure out the tile size in X and Y. Make them slightly smaller so we end up 
    % plotting a grid of non-overlapping squares
    pShrinkBy = 0.05; % proportion by which to shrink the tiles

    %tileSizeX = getTileSizeFromPositionList( pixPos(:,1) );
    %tileSizeY = getTileSizeFromPositionList( pixPos(:,2) );
    tileSizeX = 120;
    tileSizeY = 120;
    tileSizeX = tileSizeX * (1-pShrinkBy);
    tileSizeY = tileSizeY * (1-pShrinkBy);

    % Center the tile grid on the sample given the fact that we just made
    % the tiles smaller
    pixPos(:,1) = pixPos(:,1)+tileSizeX*(pShrinkBy/2);
    pixPos(:,2) = pixPos(:,2)-tileSizeY*(pShrinkBy/2);

    obj.plotOverlayHandles.(mfilename)=plotTile(pixPos);

    hold(obj.imageAxes,'off')

    drawnow

    % Nested functions follow
    function H=plotTile(cPix)
        % cPix - corner pixel location
        % H=plot(cornerPix(1),cornerPix(2),'or','Parent',obj.imageAxes);
        xT = [cPix(1), cPix(1)+tileSizeX, cPix(1)+tileSizeX, cPix(1), cPix(1)];
        yT = [cPix(2), cPix(2), cPix(2)+tileSizeY, cPix(2)+tileSizeX, cPix(2)];
        H=plot(xT,yT,'-b','Parent',obj.imageAxes,'LineWidth',1.5);

    end


end %overlayStagePositionOnImage
