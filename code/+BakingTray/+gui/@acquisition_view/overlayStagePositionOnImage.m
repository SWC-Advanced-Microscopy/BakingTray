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

    
    % WARNING -- We assume images are square
    if size(obj.model.downSampledTileBuffer,1) ~= size(obj.model.downSampledTileBuffer,2)
        fprintf('Can not overlay stage pos. Tiles are not square\n')
        return
    end
        
    tileSize = size(obj.model.downSampledTileBuffer,1);
    
    obj.plotOverlayHandles.(mfilename) = plotFOV(pixPos);

    hold(obj.imageAxes,'off')

    drawnow

    % Nested functions follow
    function H=plotFOV(cPix)
        % cPix - corner pixel location
        % H=plot(cornerPix(1),cornerPix(2),'or','Parent',obj.imageAxes);
        xT = [cPix(1), cPix(1)+tileSize, cPix(1)+tileSize, cPix(1), cPix(1)];
        yT = [cPix(2), cPix(2), cPix(2)+tileSize, cPix(2)+tileSize, cPix(2)];
        H=plot(xT,yT,'-','Parent',obj.imageAxes,'LineWidth',2,'Color',0.2,0.2,1);
    end % plotFOV


end %overlayStagePositionOnImage
