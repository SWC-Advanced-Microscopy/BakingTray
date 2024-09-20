function overlayStageBoundariesOnImage(obj)
    % Overlay a line indicating the extent of stage motions that are possible
    %
    %
    % Purpose
    % Display to the user the extent of stage motions on the preview window.
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


    % Set up
    hold(obj.imageAxes,'on')
    obj.removeOverlays(mfilename)

    % The limits of the stages
    x_lim = [obj.model.xAxis.getMinPos,obj.model.xAxis.getMaxPos];
    y_lim = [obj.model.yAxis.getMinPos, obj.model.yAxis.getMaxPos];

    % Shift the negative y limit out by one tile size, otherwise the 
    % border will not be intuitive to the user. This is because the
    % position of the tile is counted as the top/left corner. 
    y_lim(1) = y_lim(1) - obj.model.recipe.TileStepSize.Y;
    

    % The positive X limit is way off the screen (up at the top) and this
    % confuses users. So we will fake it and place it just beyond the edge 
    % of the slide frosted area.
    slideEdge = obj.model.recipe.SYSTEM.slideFrontLeft{1};
    if ~isnan(slideEdge)
        bufferMM = 7 * obj.model.recipe.SYSTEM.cutterSide;
        x_lim(2) = slideEdge + bufferMM;
    end

    % Top left pixel is maxPos for both axes and bottom right is minPos.
    % The line we will draw therefore will be:
    x = [x_lim(2),x_lim(1),x_lim(1),x_lim(2),x_lim(2)];
    y = [y_lim(2),y_lim(2),y_lim(1),y_lim(1),y_lim(2)];

    pixPos=obj.model.convertStagePositionToImageCoords([x(:),y(:)]);

    obj.plotOverlayHandles.(mfilename) = plot(pixPos(:,1),pixPos(:,2),'--r','Parent',obj.imageAxes,'LineWidth',2);
    obj.plotOverlayHandles.(mfilename)(end+1) = text(pixPos(1,1),pixPos(1,2)-50,'Stage Boundaries','Color','r','parent',obj.imageAxes);
    obj.plotOverlayHandles.(mfilename)(end+1) = text(mean(pixPos(:,1)),pixPos(2,2)-50,'Stage Boundaries','Color','r','parent',obj.imageAxes);

    hold(obj.imageAxes,'off')

    drawnow

end %overlayStageBoundariesOnImage
