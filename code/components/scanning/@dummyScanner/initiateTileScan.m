function initiateTileScan(obj)


    if strcmp(obj.parent.recipe.mosaic.scanmode,'ribbon')
        fprintf('** dummyScanner can not handle ribbon scanning\n')
        return
    end

    % Performs a tile scan. This method rolls together what is done in SIBT.initiateTileScan
    % and the ScanImage callback SIBT.tileAcqDone.
    obj.acquireTile % Because we are already at the front/left position

    if ~isempty(obj.parent.positionArray)
        obj.parent.lastTilePos.X = obj.parent.positionArray(obj.parent.currentTilePosition,1);
        obj.parent.lastTilePos.Y = obj.parent.positionArray(obj.parent.currentTilePosition,2);
        obj.parent.lastTileIndex = obj.parent.currentTilePosition;
    else
        fprintf('BT.positionArray is empty. Not logging last tile positions. Likely hBT.runTileScan was not run.\n')
    end

    %Initiate move to the next X/Y position (blocking motion)
    obj.parent.moveXYto(obj.parent.currentTilePattern(obj.parent.currentTilePosition+1,1), ...
        obj.parent.currentTilePattern(obj.parent.currentTilePosition+1,2), true);


    % Import the last frames and downsample them
    debugMessages=false;

    if obj.parent.importLastFrames
        msg='';
        planeNum=1; %This counter indicates the current z-plane

        for z = 1 : obj.numOpticalPlanes
            tTile = obj.lastAcquiredTile;

            for ii = 1:obj.numChannels % Loop through channels
                if debugMessages
                    fprintf('\t%s placing channel %d in scanner downSampledTileBuffer plane %d\n', ...
                        mfilename,lastStripe.roiData{1}.channels(ii), planeNum)
                end

                % TODO: fix this ugly mess
                if obj.settings.tileAcq.tileFlipUD
                    obj.parent.downSampledTileBuffer(:, :, planeNum, ii) = ...
                        int16(flipud( imresize(rot90(tTile,obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear') ));
                elseif obj.settings.tileAcq.tileFlipLR
                     obj.parent.downSampledTileBuffer(:, :, planeNum, ii) = ...
                        int16(fliplr( imresize(rot90(tTile,obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear') ));
                else
                     obj.parent.downSampledTileBuffer(:, :, planeNum,ii) = ...
                        int16(imresize(rot90(tTile,obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear'));
                end

            end

            planeNum=planeNum+1;
        end % z=1:length...
    end % if obj.parent.importLastFrames



    % Increment the counter and make the new position the current one
    obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;


    % Store stage positions. this is done after all tiles in the z-stack have been acquired
    doFakeLog=false; % Takes about 50 ms each time it talks to the PI stages. 
    % Setting doFakeLog to true will save about 15 minutes over the course of an acquisition but
    % You won't get the real stage positions
    obj.parent.logPositionToPositionArray(doFakeLog)

    if obj.writeData==true
        positionArray = obj.parent.positionArray;
        save(fullfile(obj.parent.currentTileSavePath,'tilePositions.mat'),'positionArray')
    end

    % Initiate the next position so long as we aren't paused
    while obj.acquisitionPaused
        pause(0.25)
    end

    obj.logMessage('acqDone',dbstack,2,'->Completed acqDone and initiating next tile acquisition<-');

    if obj.parent.currentTilePosition>=size(obj.parent.currentTilePattern,1)
        fprintf('hBT.currentTilePosition > number of positions. Breaking in dummyScanner.tileAcqDone\n')
        obj.parent.acquisitionInProgress=false;
        return
    end

    obj.initiateTileScan  % Start the next position. See also: BT.runTileScan


end % initiateTileScan