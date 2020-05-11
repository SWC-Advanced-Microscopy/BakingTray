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


    tDepth = obj.numOpticalPlanes * (obj.parent.currentSectionNumber-1) + obj.currentOpticalPlane;
    if size(obj.imageStackData,3)<tDepth
        fprintf('Current desired depth %d is out of bounds. Loaded stack has %d planes.\n',...
            tDepth, size(obj.imageStackData,3))
        return
    end
    thisSection = obj.imageStackData(:,:,tDepth);



    [X,Y]=obj.parent.getXYpos;
    xPosInMicrons = abs(X)*1E3 ;
    yPosInMicrons = abs(Y)*1E3 ;

    xPosInPixels = round(xPosInMicrons / obj.imageStackVoxelSizeXY);
    yPosInPixels = round(yPosInMicrons / obj.imageStackVoxelSizeXY);


    % Position of the tile in the slice:
    xRange = [xPosInPixels,xPosInPixels+obj.xStepInPixels];
    yRange = [yPosInPixels,yPosInPixels+obj.yStepInPixels];


    tile = thisSection(xRange(1):xRange(2),yRange(1):yRange(2));

    obj.lastAcquiredTile=tile; % So it's available to dummyScanner.initiateTileScan

    if obj.displayAcquiredImages
        % Open figure window as needed
        obj.createFigureWindow

        % Update the current section
        obj.hWholeSectionPlt.CData=thisSection;
        set(obj.hWholeSectionAx, ...
            'XLim', obj.sectionImage_xlim, ...
            'YLim', obj.sectionImage_ylim, ...
            'CLim', obj.stack_clim)

        % Update the current tile position
        obj.hTileLocationBox.XData=mean(yRange);
        obj.hTileLocationBox.YData=mean(xRange);

        obj.hCurrentFramePlt.CData=tile;
        set(obj.hCurrentFrameAx, ...
            'XLim', [1,size(tile,2)], ...
            'YLim', [1,size(tile,1)], ...
            'CLim', obj.stack_clim)
        drawnow
    end


    success=true;

    if nargout>0
        varargout{1}=success;
    end

    if obj.writeData
        fname = sprintf('%s_%05d.tif',fullfile(obj.logFilePath,obj.logFileStem),obj.logFileCounter);
        obj.logFileCounter = obj.logFileCounter + 1;

        % Build a meta-data structure containing the fields StitchIt needs to assemble the stacks
        metaData = sprintf(['SI.hChannels.channelOffset = 0\n', ...
                            'SI.hFastZ.numFramesPerVolume = []\n', ...
                            'SI.hChannels.channelSave = 1\n', ...
                            'SI.hChannels.channelsActive = 1\n']);
        writeSignedTiff(tile,fname,metaData)
    end
end % acquireTile