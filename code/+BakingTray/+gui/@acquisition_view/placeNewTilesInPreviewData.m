function placeNewTilesInPreviewData(obj,~,~)
    % When new tiles are acquired they are placed into the correct location in
    % the obj.previewImageData array. This is run when the tile position increments
    % So it only runs once per X/Y position. 

    if obj.verbose
        fprintf('In acquisition_view.placeNewTilesInPreviewData callback\n')
    end

    %TODO: temporarily do not build preview if ribbon-scanning
    if strcmp(obj.model.recipe.mosaic.scanmode,'ribbon')
        return
    end

    obj.updateStatusText
    if obj.model.processLastFrames==false
        return
    end

    %If the current tile position is 1 that means it was reset from its final value at the end of the last
    %section to 1 by BT.runTileScan. So that indicates the start of a section. If so, we wipe all the 
    %buffer data so we get a blank image
    if obj.model.currentTilePosition==1
        obj.initialisePreviewImageData;
    end

    if obj.model.lastTilePos.X>0 && obj.model.lastTilePos.Y>0
        % Caution changing these lines: tiles may be rectangular
        %Where to place the tile
        y = (1:size(obj.model.downSampledTileBuffer,1)) + obj.previewTilePositions(obj.model.lastTileIndex,2);
        x = (1:size(obj.model.downSampledTileBuffer,2)) + obj.previewTilePositions(obj.model.lastTileIndex,1);

        % NOTE: do not write to obj.model.downSampled tiles. Only the scanner should write to this.

        %Place the tiles into the full image grid so it can be plotted (there is a listener on this property to update the plot)
        obj.previewImageData(y,x,:,:) = obj.model.downSampledTileBuffer;

        %Only update the section image every so often to avoid slowing down the acquisition
        n=obj.model.currentTilePosition;
        if n==1 || mod(n,10)==0 || n==length(obj.model.positionArray)
            obj.updateSectionImage
        end

        obj.model.downSampledTileBuffer(:) = 0; %wipe the buffer 
    end % obj.model.lastTilePos.X>0 && obj.model.lastTilePos.Y>0

end %placeNewTilesInPreviewData