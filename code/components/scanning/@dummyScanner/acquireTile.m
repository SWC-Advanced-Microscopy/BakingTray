function varargout = acquireTile(obj,~)
    %If image stack data have been added, then we can fake acquisition of an image. Otherwise skip.
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

    obj.lastAcquiredTile=tile;
    if obj.displayAcquiredImages
    % Open figure window as needed
        f=findobj('Tag','CurrentDummyImFig')
        if isempty(f)
            obj.hCurrentImFig = figure;
            obj.hCurrentImFig.Tag='CurrentDummyImFig';
        else
            % Focus on figure window
            figure(f)
            clf(f)
        end

        tileIm=imagesc(tile);
        tileIm.Tag='tileImage';
        %set(gca,'Clim',[min(thisSection(:)), max(thisSection(:))])
        axis equal off
        colormap gray
        set(gcf,'color',[1,0.9,0.9]*0.1)
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