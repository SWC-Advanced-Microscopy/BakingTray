function spawnTilePickerWindow(obj)
    % Spawn a tile picker window to allow the user to uncheck tiles to image
    %
    % Purpose
    % Allows the user to image only subsets of tiles.
    %
    % Instructions
    % - Run a preview scan as normal. Then type at the command line:
    %   hBTview.view_acquire.spawnTilePickerWindow 
    % - Resize the window as needed
    % - Left-click on the tile numbers to set them to grey (non-imaged)
    % - Right-click on grey numbers to reset them to red (imaged)
    % - The function produces a vector in the base workspace called
    %   tilesToRemove. This contains the indexes of all grey tiles.
    % - When you are ready do: hBT.recipe.mosaic.tilesToRemove=tilesToRemove;
    %   to store your changes in the recipe. Re-run the preview scan to confirm
    % - If you wish to image all tiles do: hBT.recipe.mosaic.tilesToRemove=[];
    %
    %
    % WARNINGS
    % - Has not been tested with acquisition resume
    %


    % Ensure we have a tile pattern
    obj.overlayTileGridOnImage(obj.model.currentTilePattern)

    F=figure(19342);
    clf(F)

    copyobj(obj.imageAxes,F)
    colormap gray

    AX = get(F,'Children');

    set(F, 'WindowButtonDownFcn', @buttonPressed)

end %spawnTilePickerWindow

    function getcoords(src)
        this = hittest;
        if strcmp(get(this,'type'),'text');
            currentColor = this.Color;
            if strcmp(src.SelectionType,'alt')
                this.Color='r';
            elseif strcmp(src.SelectionType,'normal')
                this.Color=[1,1,1]*0.5;
            end
        end


    end

    function buttonPressed(src,~)
        getcoords(src)

        % dump tiles to remove as a vector in base workspace
        dumpRemoveVectorToBase(src)
    end


    function dumpRemoveVectorToBase(src)
        figItems = src.Children.Children;
        tilesToRemove=-1; % -1 indicates that all tiles will be imaged so if nothing is added to the vector, this is what happens.
        for ii=1:length(figItems)
            if isa(figItems(ii),'matlab.graphics.primitive.Text') % Is it a text item?
                if ~isequal(figItems(ii).Color, [1,0,0]) % if it's not red then we don't image this tile
                    tilesToRemove(end+1)=str2num(figItems(ii).String);
                end
            end
        end
        assignin('base','tilesToRemove',tilesToRemove)
    end
