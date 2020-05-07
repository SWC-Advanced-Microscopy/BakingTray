function overlayTileGridOnImage(obj,tileGrid)
    % Overlay a series of squares corresponding to the tiles over the 
    % preview image. 
    %
    % Inputs
    % tileGrid - The output of recipe.tilePattern. First column is x-stage pos in mm
    %            and second column is y-stage pos in mm.
    %
    %
    % TESTING
    % TODO -- tidy and doc if we are to keep this


    if isempty(obj.model.autoROI)
        return
    end

    hold(obj.imageAxes,'on')

    obj.removeOverlays('tilegrid')

    pixPos=obj.model.convertStagePositionToImageCoords(tileGrid);


    %pause(0.2), drawnow % temporary for diagnostics

    % TODO: this needs to be based on absolute units or scaled by the number
    % of boxes. Otherwise it doesn't look nice. Ends up overlapping with the 
    % bounding box at larger box sizes.

    % Figure out the tile size in X and Y. Make them slightly smaller so we end up 
    % plotting a grid of non-overlapping squares
    pShrinkBy = 0.05; % proportion by which to shrink the tiles

    tileSizeX = getTileSizeFromPositionList( pixPos(:,1) );
    tileSizeY = getTileSizeFromPositionList( pixPos(:,2) );
    tileSizeX = tileSizeX * (1-pShrinkBy);
    tileSizeY = tileSizeY * (1-pShrinkBy);

    % Center the tile grid on the sample given the fact that we just made
    % the tiles smaller
    pixPos(:,1) = pixPos(:,1)+tileSizeX*(pShrinkBy/2);
    pixPos(:,2) = pixPos(:,2)-tileSizeY*(pShrinkBy/2);

    overlayTileNumbers=true;
    obj.plotOverlayHandles.tilegrid = [];
    for ii=1:size(pixPos,1)
        H=plotTile(pixPos(ii,:),ii,overlayTileNumbers);
        obj.plotOverlayHandles.tilegrid = [obj.plotOverlayHandles.tilegrid,H];
    end

    % Highlight first and last tiles. Optional for now. 
    % TODO: we really want to identify any separate ROIs
    % and plot the first and last tiles of each. However, it would
    % make sense to have an external function do this, as we'll
    % want the feature when moving between positions too
    if ~overlayTileNumbers % won't work with tile numbers right now
        % First tile will be green and last tile red
        obj.plotOverlayHandles.tilegrid(1).Color='g';
        obj.plotOverlayHandles.tilegrid(end).Color='r';

        % Add an arror going from the middle of the first tile to the middle of the second
        % ignore the last plot point to centre the arrow on the tile. The last point
        % is just there to complete tile square.
        pA(1) = mean(obj.plotOverlayHandles.tilegrid(1).XData(1:4));
        pA(2) = mean(obj.plotOverlayHandles.tilegrid(1).YData(1:4));

        pB(1) = mean(obj.plotOverlayHandles.tilegrid(2).XData(1:4));
        pB(2) = mean(obj.plotOverlayHandles.tilegrid(2).YData(1:4));
        d = pB-pA;
        obj.plotOverlayHandles.tilegrid(end+1)=quiver(pA(1),pA(2), d(1),d(2),0,...
            'MaxHeadSize', 1.5, 'Color', 'c', ...
            'LineWidth',4,'Parent',obj.imageAxes);


        pA(1) = mean(obj.plotOverlayHandles.tilegrid(size(pixPos,1)-1).XData(1:4));
        pA(2) = mean(obj.plotOverlayHandles.tilegrid(size(pixPos,1)-1).YData(1:4));

        pB(1) = mean(obj.plotOverlayHandles.tilegrid(size(pixPos,1)).XData(1:4));
        pB(2) = mean(obj.plotOverlayHandles.tilegrid(size(pixPos,1)).YData(1:4));
        d = pB-pA;
        obj.plotOverlayHandles.tilegrid(end+1)=quiver(pA(1),pA(2), d(1),d(2),0,...
            'MaxHeadSize', 1.5, 'Color', 'c', ...
            'LineWidth',4,'Parent',obj.imageAxes);
    end

    hold(obj.imageAxes,'off')

    % Nested functions follow
    function H=plotTile(cPix,tileIndex,doTileNumber)
        % cPix - corner pixel location
        %H=plot(cornerPix(1),cornerPix(2),'or','Parent',obj.imageAxes);
        xT = [cPix(1), cPix(1)+tileSizeX, cPix(1)+tileSizeX, cPix(1), cPix(1)];
        yT = [cPix(2), cPix(2), cPix(2)+tileSizeY, cPix(2)+tileSizeX, cPix(2)];
        H=plot(xT,yT,'-b','Parent',obj.imageAxes,'LineWidth',1.5);
        if doTileNumber
            H(2)=text(mean(xT(1:4)), mean(yT(1:4)), num2str(tileIndex),'Parent',obj.imageAxes, ...
                'Color','r', 'HorizontalAlignment' ,'Center','FontWeight','bold');
        end
    end

    function tSize = getTileSizeFromPositionList(pList)
        % pList is a list of X or Y stage or pixel positions
        % from this we obtain the tile size as the largest 
        % most common interval between tiles
        d = diff(pList);
        d(d==0) = [];
        tSize = mode(abs(d));
    end

end %overlayPointsOnImage


