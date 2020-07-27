function updateTileSizeLabelText(obj,scnSet)
    % This isn't a callback, it is a helper method to other callbacks.
    % If the selected tile size in the pop-up menu doesn't match what the 
    % scanner is going to be acquiring then we highlight the label by 
    % making it red. Otherwise it's white.
    %
    % Inputs
    % If scnSet is provided then it doesn't have to be obtained from the scanner

    if nargin<2
        if obj.model.isScannerConnected
            scnSet=obj.model.scanner.returnScanSettings;
        else
            return
        end
    end


    % If possible update the label text. Don't proceed if no scanner is connected
    if ~obj.model.isScannerConnected
        return
    end

    % Get the tile size value from the pop-up menu
    selectedTileSize=[];
    for ii=1:length(obj.recipeEntryBoxes.other)
        tBox = obj.recipeEntryBoxes.other{ii};
        if strcmp(tBox.Tag,'tilesize') && ~isempty(tBox.UserData)
            selectedTileSize = tBox.UserData(tBox.Value);
            break
        end
    end
    if isempty(selectedTileSize)
        return
    end

    if selectedTileSize.pixelsPerLine==scnSet.pixelsPerLine && ...
         selectedTileSize.linesPerFrame==scnSet.linesPerFrame && ...
         selectedTileSize.slowMult==scnSet.slowMult && ...
         selectedTileSize.fastMult==scnSet.fastMult && ...
         selectedTileSize.zoomFactor==scnSet.zoomFactor

        obj.recipeTextLabels.other{ii}.String = 'Tile Size';
        obj.recipeTextLabels.other{ii}.Color = 'w';
     else
         obj.recipeTextLabels.other{ii}.String = '*Tile Size';
         obj.recipeTextLabels.other{ii}.Color = 'r';
    end
end
