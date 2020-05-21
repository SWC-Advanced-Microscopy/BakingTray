function varargout = acquireTile(obj,~,~)
    % Acquire a tile from an attached image stack
    %
    % function success = dummyScanner.acquireTile(obj,~,~)
    %
    % Purpose
    % If image stack data have been added using dummyScanner.attachPreviewStack then this
    % method can acquire a tile from that stack. The stack is stored in the property
    % dummyScanner.imageStackData, from which a tile is acquired based on the current
    % stage coordinates. The loaded image stack is 3D (x/y planes with a number of stacks).
    %
    % Note that the stack is padded in x/y in attachPreviewStack in order to allow tiles
    % to be taken at the edges the over the originally-imaged area.
    %
    % Inputs
    % None
    %
    %
    % Outputs
    % success - true if a tile was acquired

    success=false;

    % If no image stack is attached then we bail out

    if isempty(obj.imageStackData)
        if nargout>0
            varargout{1}=success;
        end
        return
    end


    % Extract the desired section from the stack. Bail out if the section is out of range.
    tDepth = obj.numOpticalPlanes * (obj.parent.currentSectionNumber-1) + obj.currentOpticalPlane;
    if size(obj.imageStackData,3)<tDepth
        fprintf('Current desired depth %d is out of bounds. Loaded stack has %d planes.\n',...
            tDepth, size(obj.imageStackData,3))
        return
    end
    thisSection = obj.imageStackData(:,:,tDepth);


    % Get the stage x/y position
    [X,Y]=obj.parent.getXYpos;
    xPosInMicrons = abs(X)*1E3 ;
    yPosInMicrons = abs(Y)*1E3 ;


    % Convert to pixel coords. Round the numbers because we will use these
    % variables to index the image.
    xPosInPixels = round(xPosInMicrons / obj.imageStackVoxelSizeXY);
    yPosInPixels = round(yPosInMicrons / obj.imageStackVoxelSizeXY);


    % Position of the tile in the slice:
    xRange = [xPosInPixels,xPosInPixels+obj.xStepInPixels];
    yRange = [yPosInPixels,yPosInPixels+obj.yStepInPixels];


    % Check that the coordinates are within range of the image
    if xRange(1)<1
        fprintf('x tile range has coordinate is <1. Not acquiring tile\n')
        return
    end

    if yRange(1)<1
        fprintf('y tile range has coordinate is <1. Not acquiring tile\n')
        return
    end

    if xRange(end)>size(thisSection,1)
        fprintf('x tile range has coordinate is <1. Not acquiring tile\n')
        return
    end

    if yRange(end)>size(thisSection,2)
        fprintf('y tile range has coordinate is <1. Not acquiring tile\n')
        return
    end


    % Pull out the tile from the section
    tile = thisSection(xRange(1):xRange(2),yRange(1):yRange(2));

    % Place the acquired tile into the lastAcquiredTile property so it's available
    % to dummyScanner.initiateTileScan
    obj.lastAcquiredTile=tile;


    % If the displayAcquiredImages property is true, we display images to screen. This option
    % can be disabled by setting this to false in order to speed up bake acquisitions if needed.
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


    % Optionally write the data to disk. The dummyScanner.setUpTileSaving method sets writeData to true. This is triggered
    % during a BT.bake. Therefore any time a bake is iniated data will be saved. The dummyScanner method therefore has an 
    % additional "skipSaving" property which allows us to avoid saving if needed for debug reasons.
    if obj.writeData && exist(obj.logFilePath,'dir')
        fname = sprintf('%s_%05d.tif',fullfile(obj.logFilePath,obj.logFileStem),obj.logFileCounter);
        obj.logFileCounter = obj.logFileCounter + 1;

        % For the dummyScanner there is an additional option to skip saving of data.
        if obj.skipSaving == false
            % Build a meta-data structure containing the fields StitchIt needs to assemble the stacks
            metaData = sprintf(['SI.hChannels.channelOffset = 0\n', ...
                                'SI.hFastZ.numFramesPerVolume = []\n', ...
                                'SI.hChannels.channelSave = 1\n', ...
                                'SI.hChannels.channelsActive = 1\n']);
            writeSignedTiff(tile,fname,metaData)
        end
    end

end % acquireTile
