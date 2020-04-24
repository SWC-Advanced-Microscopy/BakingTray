function initiateTileScan(obj)
    % This method rolls together what takes place in SIBT.initiateTileScan and SIBT.tileAcqDone
    %
    % Purpose
    % Moves the virtual stages. Acquires a tile. Moves the stages. Calls itself
    % recursively until all done. 

    verbose = false;

    if strcmp(obj.parent.recipe.mosaic.scanmode,'ribbon')
        fprintf('** dummyScanner can not handle ribbon scanning\n')
        return
    end

    % Performs a tile scan. This method rolls together what is done in SIBT.initiateTileScan
    % and the ScanImage callback SIBT.tileAcqDone.
    obj.acquireTile % Acquire a tile right away because we are already at the front/left position


    % Now log this tile position so we later can save it to disk
    obj.parent.lastTilePos.X = obj.parent.positionArray(obj.parent.currentTilePosition,1);
    obj.parent.lastTilePos.Y = obj.parent.positionArray(obj.parent.currentTilePosition,2);
    obj.parent.lastTileIndex = obj.parent.currentTilePosition;
    if verbose
        fprintf('Acquired tile at %d/%d\n', obj.parent.lastTileIndex,size(obj.parent.positionArray,1))
    end


    %Initiate move to the *next* X/Y position
    if 1+obj.parent.currentTilePosition <= size(obj.parent.currentTilePattern,1)
        obj.parent.moveXYto(obj.parent.currentTilePattern(obj.parent.currentTilePosition+1,1), ...
            obj.parent.currentTilePattern(obj.parent.currentTilePosition+1,2), false);
    end


    % "Import" the last frames and downsample them
    if obj.parent.importLastFrames
        msg='';
        planeNum=1; %This counter indicates the current z-plane

        for z = 1 : obj.numOpticalPlanes
            for ii = 1:obj.numChannels % Loop through channels
                % TODO: fix this ugly mess
                if obj.settings.tileAcq.tileFlipUD
                    obj.parent.downSampledTileBuffer(:, :, planeNum, ii) = ...
                        int16(flipud( imresize(rot90(obj.lastAcquiredTile,obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear') ));
                elseif obj.settings.tileAcq.tileFlipLR
                    obj.parent.downSampledTileBuffer(:, :, planeNum, ii) = ...
                        int16(fliplr( imresize(rot90(obj.lastAcquiredTile,obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear') ));
                else
                    obj.parent.downSampledTileBuffer(:, :, planeNum, ii) = ...
                        int16(imresize(rot90(obj.lastAcquiredTile,obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear'));
                end
            end
            planeNum=planeNum+1;
        end % z=1:length...
    end % if obj.parent.importLastFrames



    % Store stage positions. this is done after all tiles in the z-stack have been acquired
    obj.parent.logPositionToPositionArray


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
        obj.disarmScanner;
        return
    end

  % Increment the counter and make the new position the current one
    obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;


    obj.initiateTileScan  % Start the next position. See also: BT.runTileScan


end % initiateTileScan