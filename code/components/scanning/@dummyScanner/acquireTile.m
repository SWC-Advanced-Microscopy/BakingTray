function varargout = acquireTile(obj,~,~)
    %If image stack data have been added, then we can fake acquisition of an image. Otherwise skip.
    % This is also a callback function that is accessed via the "Scanner" menu
    if isempty(obj.imageStackData)
        success=false;
        if nargout>0
            varargout{1}=success;
        end
        return
    end

    verbose=true;

    tDepth = obj.numOpticalPlanes * (obj.currentPhysicalSection-1) + obj.currentOpticalPlane;
    if size(obj.imageStackData,3)<tDepth
        fprintf('Current desired depth %d is out of bounds. Loaded stack has %d planes.\n',...
            tDepth, size(obj.imageStackData,3))
        return
    end
    thisSection = obj.imageStackData(:,:,tDepth);

    [X,Y]=obj.parent.getXYpos;
    xPosInMicrons = abs(X)*1E3 ; %ABS HACK TODO
    yPosInMicrons = abs(Y)*1E3 ; %ABS HACK TODO

    %tile step size
    xStepInMicrons = obj.parent.recipe.TileStepSize.X*1E3;
    yStepInMicrons = obj.parent.recipe.TileStepSize.Y*1E3;


    %position in slice is
    xRange = ceil([xPosInMicrons,xPosInMicrons+xStepInMicrons]/obj.imageStackVoxelSizeXY);
    yRange = ceil([yPosInMicrons,yPosInMicrons+yStepInMicrons]/obj.imageStackVoxelSizeXY);
    if xRange(1)==0
        xRange=xRange+1;
    end
    if yRange(1)==0
        yRange=yRange+1;
    end

    if verbose
        txt=sprintf('Getting tile x=%d:%d - y=%d:%d  -  image %dx%d\n', ...
            min(xRange), max(xRange), ...
            min(yRange), max(yRange), ...
            size(thisSection));
        %disp(txt)
    end
    tile = thisSection(xRange(1):xRange(2),yRange(1):yRange(2));

    obj.lastAcquiredTile=tile; % So it's available to dummyScanner.initiateTileScan

    if obj.displayAcquiredImages
        % Open figure window as needed
        obj.createFigureWindow

        % Update the current section
        obj.hWholeSectionPlt.CData=thisSection;
        set(obj.hWholeSectionAx, ...
            'XLim', [1,size(thisSection,2)], ...
            'YLim', [1,size(thisSection,1)], ...
            'CLim', obj.stack_clim)

        % Update the current tile position
        obj.hTileLocationBox.XData=mean(yRange);
        obj.hTileLocationBox.YData=mean(xRange);

        obj.hCurrentFramePlt.CData=tile;
        set(obj.hCurrentFrameAx, ...
            'XLim', [1,size(tile,2)], ...
            'YLim', [1,size(tile,1)], ...
            'CLim', obj.stack_clim)

        %set(gca,'Clim',[min(thisSection(:)), max(thisSection(:))])

        drawnow
    end

    success=true;

    if nargout>0
        varargout{1}=success;
    end

    if obj.writeData
        %SAVE
    end
end % acquireTile