function BT_SI_userFunction(src,event,varargin)


    switch event.EventName

        case 'frameAcquired'


        case 'acqModeStart'
            fprintf(' -> ScanImage/SIBT is entering acquisition mode\n')


        case 'acqModeDone'
            fprintf('ScanImage/SIBT is leaving acquisition mode\n')

        case 'acqDone'
            %Move stage at the end of a volume or tile acquisition
            hBT = BakingTray.getObject;
            hSI = src.hSI; % get the handle to the ScanImage model

            % This is an implicit loop, since this user function is called repeatedly until 
            % all tiles have been acquired.

            %Log theX and Y positions in the grid associated with these tile data
            hBT.lastTilePos.X=hBT.positionArray(hBT.currentTilePosition,1);
            hBT.lastTilePos.Y=hBT.positionArray(hBT.currentTilePosition,2);
            hBT.lastTileIndex=hBT.currentTilePosition;
            verbose=false;

            if hBT.importLastFrames
                msg='';
                for z=1:length(hSI.hDisplay.stripeDataBuffer) %Loop through depths
                    % scanimage stores image data in a data structure called 'stripeData'
                    %ptr=hSI.hDisplay.stripeDataBufferPointer; % get the pointer to the last acquired stripeData (ptr=1 for z-depth 1, ptr=5 for z-depth, etc)
                    lastStripe = hSI.hDisplay.stripeDataBuffer{z};
                    if isempty(lastStripe)
                        msg = sprintf('hSI.hDisplay.stripeDataBuffer{%d} is empty. ',z);
                    elseif ~isprop(lastStripe,'roiData')
                        msg = sprintf('hSI.hDisplay.stripeDataBuffer{%d} has no field "roiData"',z);
                    elseif ~iscell(lastStripe.roiData)
                        msg = sprintf('Expected hSI.hDisplay.stripeDataBuffer{%d}.roiData to be a cell. It is a %s.',z, class(lastStripe.roiData));
                    elseif length(lastStripe.roiData)<1
                        msg = sprintf('Expected hSI.hDisplay.stripeDataBuffer{%d}.roiData to be a cell with length >1',z);
                    end

                    if ~isempty(msg)
                        msg = [msg, 'NOT EXTRACTING TILE DATA IN USER FUNCTION'];
                        hBT.logMessage('acqDone',dbstack,6,msg);
                        break
                    end

                    for ii = 1:length(lastStripe.roiData{1}.channels) % Loop through channels
                        hBT.downSampledTileBuffer(:, :, lastStripe.frameNumberAcq, lastStripe.roiData{1}.channels(ii)) = ...
                             int16(imresize(rot90(lastStripe.roiData{1}.imageData{ii}{1},-1),...
                                [size(hBT.downSampledTileBuffer,1),size(hBT.downSampledTileBuffer,2)],'bicubic'));
                    end

                    if verbose
                        fprintf('Placed data from frameNumberAcq=%d (%d) ; frameTimeStamp=%0.4f\n', ...
                            lastStripe.frameNumberAcq, ...
                            lastStripe.frameNumberAcqMode, ...
                            lastStripe.frameTimestamp)
                    end
                end % z=1:length...
            end % if hBT.importLastFrames


            %Increement the counter and make the new position the current one
            hBT.currentTilePosition = hBT.currentTilePosition+1;
            pos=hBT.recipe.tilePattern;

            if hBT.currentTilePosition>size(pos,1)
                return
            end

            % Blocking motion
            hBT.moveXYto(pos(hBT.currentTilePosition,1),pos(hBT.currentTilePosition,2),1); 

            %store stage positions. this is done after all tiles in the z-stack have been acquired
            hBT.logPositionToPositionArray
            positionArray=hBT.positionArray;

            if hSI.hChannels.loggingEnable==true
                save(fullfile(hBT.currentTileSavePath,'tilePositions.mat'),'positionArray')
            end

            if src.hSI.active % Could have a smarter check here. e.g. stop only when all volumes 
                              % are in so we generate an error if there's a failure

                while hBT.scanner.acquisitionPaused
                    pause(0.5)
                end
                src.hSI.hScan2D.trigIssueSoftwareAcq; %Acquire all depths and channels at this X/Y position
            end
            hBT.logMessage('acqDone',dbstack,2,'->Completed acqDone<-');            
    end % switch

end