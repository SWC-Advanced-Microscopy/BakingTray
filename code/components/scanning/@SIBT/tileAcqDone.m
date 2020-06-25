function tileAcqDone(obj,~,~)
    % SIBI.tileAcqDone
    %
    % Callback that runs when hSI.acqDone fires.
    %
    % Purpose
    % This callback function is VERY IMPORTANT it constitutes part of the implicit loop
    % that performs the tile scanning. It is an "implicit" loop, since it is called 
    % repeatedly until all tiles have been acquired. There is no for loop anywhere. 
    % 
    % This function records runs aftet each x/y tile position has finished acquiring and
    % gets the stage positions, moves to the *next* stage position, and whilst that is happening
    % extracts image data from the ScanImage API. Finally, it runs
    % hSI.hScan2D.trigIssueSoftwareAcq to soft-trigger another tile position to be acquired.
    % That causes us to re-enter this callback once the frames in that tile position have been 
    % completed. 

    fprintf('\nENTERING tileAcqDone\n')
    %Log the X and Y stage positions of the current tile in the grid associated with the tile data
    if ~isempty(obj.parent.positionArray)
        obj.parent.lastTilePos.X = obj.parent.positionArray(obj.parent.currentTilePosition,1);
        obj.parent.lastTilePos.Y = obj.parent.positionArray(obj.parent.currentTilePosition,2);
        obj.parent.lastTileIndex = obj.parent.currentTilePosition;
    else
        fprintf('BT.positionArray is empty. Not logging last tile positions. Likely hBT.runTileScan was not run.\n')
    end

    %Initiate move to the next X/Y position (blocking motion)
    %the if statement stops us from attempting a move once this callback is
    %called for the final time (a self-call, see below)
    if obj.parent.currentTilePosition < size(obj.parent.currentTilePattern,1)
        obj.parent.moveXYto(obj.parent.currentTilePattern(obj.parent.currentTilePosition+1,1), ...
                obj.parent.currentTilePattern(obj.parent.currentTilePosition+1,2), true);
    end

    % Import the last frames and downsample them
    debugMessages=false;


    % Import image data from the ScanImage API
    if obj.parent.importLastFrames
        msg='';
        planeNum=1; %This counter indicates the current z-plane
        %Loop through the buffer, pulling out the first frame from each depth
        for z = 1 : obj.hC.hDisplay.displayRollingAverageFactor : length(obj.hC.hDisplay.stripeDataBuffer)

            % scanimage stores image data in a data structure called 'stripeData'
            %ptr=obj.hC.hDisplay.stripeDataBufferPointer; % get the pointer to the last acquired stripeData (ptr=1 for z-depth 1, ptr=5 for z-depth, etc)
            lastStripe = obj.hC.hDisplay.stripeDataBuffer{z};

            if debugMessages
                fprintf('%d. %s pulling in obj.hC.hDisplay.stripeDataBuffer{%d}\n', ...
                        lastStripe.acqNumber, mfilename, z)
            end

            if isempty(lastStripe)
                msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} is empty. ',z);
            elseif ~isprop(lastStripe,'roiData')
                msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} has no field "roiData"',z);
            elseif ~iscell(lastStripe.roiData) && ~isempty(iscell(lastStripe.roiData)) %% TODO -- temporarilty don't report errors if this is empty since this seems to be a ScanImage bug 04/12/17
                 msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell. It is a %s.',z, class(lastStripe.roiData));
            elseif length(lastStripe.roiData)<1
                msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell with length >1',z);
            end

            if ~isempty(msg) %if true there was an error
                msg = [msg, 'NOT EXTRACTING TILE DATA IN SIBT.tileAcqDone'];
                obj.logMessage('acqDone',dbstack,6,msg);
                break
            end

            for ii = 1:length(lastStripe.roiData{1}.channels) % Loop through channels
                if debugMessages
                    fprintf('\t%s placing channel %d in scanner downSampledTileBuffer plane %d\n', ...
                        mfilename,lastStripe.roiData{1}.channels(ii), planeNum)
                end

                % TODO: fix this ugly mess
                if obj.settings.tileAcq.tileFlipUD
                    obj.parent.downSampledTileBuffer(:, :, planeNum, lastStripe.roiData{1}.channels(ii)) = ...
                        int16(flipud( imresize(rot90(lastStripe.roiData{1}.imageData{ii}{1},obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear') ));
                elseif obj.settings.tileAcq.tileFlipLR
                     obj.parent.downSampledTileBuffer(:, :, planeNum, lastStripe.roiData{1}.channels(ii)) = ...
                        int16(fliplr( imresize(rot90(lastStripe.roiData{1}.imageData{ii}{1},obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear') ));
                else
                     obj.parent.downSampledTileBuffer(:, :, planeNum, lastStripe.roiData{1}.channels(ii)) = ...
                        int16(imresize(rot90(lastStripe.roiData{1}.imageData{ii}{1},obj.settings.tileAcq.tileRotate),...
                            [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bilinear'));
                end
                % Note that each time the stages move to the next position, a listener in BT places the 
                % data in obj.parent.downSampledTileBuffer into a preview image of the whole section. 
                % Once it is done this, it replaces obj.parent.downSampledTileBuffer with zeros. 

            end

            if obj.verbose
                fprintf('%d - Placed data from frameNumberAcq=%d (%d) ; frameTimeStamp=%0.4f\n', ...
                    obj.parent.currentTilePosition, ...
                    lastStripe.frameNumberAcq, ...
                    lastStripe.frameNumberAcqMode, ...
                    lastStripe.frameTimestamp)
            end
            planeNum=planeNum+1;
        end % z=1:length...
    end % if obj.parent.importLastFrames


    %Optionally reset tripped PMTs
    if obj.settings.hardware.doResetTrippedPMT
        obj.resetTrippedPMTs
    end


    if obj.hC.hChannels.loggingEnable==true
        positionArray = obj.parent.positionArray;
        save(fullfile(obj.parent.currentTileSavePath,'tilePositions.mat'),'positionArray')
    end


    % Increment the counter and make the new position the current one
    obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;

    % Store stage positions. this is done after all tiles in the z-stack have been acquired
    doFakeLog=false; % Takes about 50 ms each time it talks to the PI stages. 
    % Setting doFakeLog to true will save about 15 minutes over the course of an acquisition but
    % you won't get the real stage positions
    % The first tile was logged in BT.runTileScan.
    obj.parent.logPositionToPositionArray(doFakeLog)



    % Initiate the next position (obj.initiateTileScan) so long as we aren't paused
    nPauses=0; % A counter to poll the laser every few seconds so it doesn't turn off if it has a watchdog timer enabled
    while obj.acquisitionPaused
        nPauses = nPauses+1;
        if nPauses>100
            nPauses=0;
            [isReady,msg]=obj.parent.laser.isReady; % Ping laser so it doesn't power-off if we are paused a long time
            continue
        end
        pause(0.25)
    end

    % Write message to the log file using the logger class
    obj.logMessage('acqDone',dbstack,2,'->Completed acqDone and initiating next tile acquisition<-');

    obj.hC.hScan2D.trigIssueSoftwareAcq
