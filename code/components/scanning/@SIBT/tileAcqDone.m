function tileAcqDone(obj,~,~)
    % This callback function is VERY IMPORTANT it constitutes part of the implicit loop
    % that performs the tile scanning. It is an "implicit" loop, since it is called 
    % repeatedly until all tiles have been acquired.

    %Log the X and Y positions in the grid associated with the tile data from the last acquired position
    if ~isempty(obj.parent.positionArray)
        obj.parent.lastTilePos.X = obj.parent.positionArray(obj.parent.currentTilePosition,1);
        obj.parent.lastTilePos.Y = obj.parent.positionArray(obj.parent.currentTilePosition,2);
        obj.parent.lastTileIndex = obj.parent.currentTilePosition;
    else
        fprintf('BT.positionArray is empty. Not logging last tile positions. Likely hBT.runTileScan was not run.\n')
    end


    switch obj.parent.recipe.mosaic.scanmode
        case 'tile'
            %Initiate move to the next X/Y position (blocking motion)
            obj.parent.moveXYto(obj.currentTilePattern(obj.parent.currentTilePosition+1,1), ...
                obj.currentTilePattern(obj.parent.currentTilePosition+1,2), true);
        case 'ribbon'
            %Initiate move to the next X position. Non-blocking, keep Y unchanged.
            obj.parent.moveXto(obj.currentTilePattern(obj.parent.currentTilePosition+1,1), false);
        otherwise
            % This can not happen. 
    end


    % Import the last frames and downsample them
    if obj.parent.importLastFrames && strcmp(obj.parent.recipe.mosaic.scanmode,'tile') %TODO: hack until ribbon is working
        msg='';
        for z=1:length(obj.hC.hDisplay.stripeDataBuffer) %Loop through depths
            % scanimage stores image data in a data structure called 'stripeData'
            %ptr=obj.hC.hDisplay.stripeDataBufferPointer; % get the pointer to the last acquired stripeData (ptr=1 for z-depth 1, ptr=5 for z-depth, etc)
            lastStripe = obj.hC.hDisplay.stripeDataBuffer{z};
            if isempty(lastStripe)
                msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} is empty. ',z);
            elseif ~isprop(lastStripe,'roiData')
                msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} has no field "roiData"',z);
            elseif ~iscell(lastStripe.roiData)
                 msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell. It is a %s.',z, class(lastStripe.roiData));
            elseif length(lastStripe.roiData)<1
                msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell with length >1',z);
            end

            if ~isempty(msg)
                msg = [msg, 'NOT EXTRACTING TILE DATA IN SIBT.tileAcqDone'];
                obj.logMessage('acqDone',dbstack,6,msg);
                break
            end

            for ii = 1:length(lastStripe.roiData{1}.channels) % Loop through channels
                obj.parent.downSampledTileBuffer(:, :, lastStripe.frameNumberAcq, lastStripe.roiData{1}.channels(ii)) = ...
                    int16(imresize(rot90(lastStripe.roiData{1}.imageData{ii}{1},-1),...
                        [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear'));
            end

            if obj.verbose
                fprintf('%d - Placed data from frameNumberAcq=%d (%d) ; frameTimeStamp=%0.4f\n', ...
                    obj.parent.currentTilePosition, ...
                    lastStripe.frameNumberAcq, ...
                    lastStripe.frameNumberAcqMode, ...
                    lastStripe.frameTimestamp)
            end
        end % z=1:length...
    end % if obj.parent.importLastFrames


    % Increment the counter and make the new position the current one
    obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;

    if obj.parent.currentTilePosition>size(obj.currentTilePattern,1)
        fprintf('hBT.currentTilePosition > number of positions. Breaking in SIBT.tileAcqDone\n')
        return
    end



    % Store stage positions. this is done after all tiles in the z-stack have been acquired
    doFakeLog=false; % Takes about 50 ms each time it talks to the PI stages. 
    % Setting doFakeLog to true will save about 15 minutes over the course of an acquisition but
    % You won't get the real stage positions
    obj.parent.logPositionToPositionArray(doFakeLog)

    if obj.hC.hChannels.loggingEnable==true
        positionArray = obj.parent.positionArray;
        save(fullfile(obj.parent.currentTileSavePath,'tilePositions.mat'),'positionArray')
    end


    % Initiate the next position
    while obj.acquisitionPaused
        pause(0.25)
    end

    obj.logMessage('acqDone',dbstack,2,'->Completed acqDone and initiating next tile acquisition<-');

    obj.initiateTileScan  % Start the next position (initiates a motion if ribbon scanning)
                          % See also: BT.runTileScan


