function [tilePosArray,tileIndexArray] = tilePattern(obj,quiet)
    % Calculate a tile grid for imaging. The imaging will proceed in an "S" over the sample.
    %
    % function [tilePosArray,tileIndexArray] = recipe.tilePattern(obj,quiet)
    %
    %
    % Purpose
    % Calculate the position grid needed to tile a sample of a given size, with a given
    % field of view, and a given overlap between adjacent tiles. TileStepSize and 
    % NumTiles are dependent properties of recipe and are based on external helper classes.
    %
    %
    % Outputs
    % tilePosArray   - One row per position. first column is X stage positions 
    %                  second Y stage positions. These are in mm.
    % tileIndexArray - The index of each tile on the grid. Columns as in tilePosArray.
    %
    %
    % Note:
    % We define X and Y (e.g. obj.NumTiles.Y and obj.NumTiles.X) with respect to the user's
    % view standing in front of the scope. So X is the stage that translates left/right and
    % Y is the stage that translated toward and away from the user. 
    %
    % 
    % Rob Campbell - Basel

    if nargin<2
        quiet=false;
    end

    % Call recipe.recordScannerSettings to populate the imaging parameter fields such as 
    % recipe.ScannerSettings, recipe.VoxelSize, etc. We then use these values
    % to build up the tile scan pattern.
    success=obj.recordScannerSettings;

    if ~success
        tilePosArray=[];
        tileIndexArray=[];
        if ~quiet
            fprintf('ERROR in recipe.tilePattern: no scanner connected. Please connect a scanner to BakingTray\n')
        end
        return
    end

    if isempty(obj.FrontLeft.X) ||isempty(obj.FrontLeft.Y)
        tilePosArray=[];
        tileIndexArray=[];
        if ~quiet
            fprintf('ERROR in recipe.tilePattern: no front-left position defined. Can not calculate tile pattern.\n')
        end
        return
    end


    %Generate the appropriate style of tile array
    switch obj.mosaic.scanmode
        case 'tile'
            [tilePosArray,tileIndexArray] = generateTileGrid(obj);
        case 'ribbon'
            [tilePosArray,tileIndexArray] = generateRibbonPattern(obj);
        otherwise
        tilePosArray=[];
        tileIndexArray=[];
        if ~quiet
            fprintf('ERROR in recipe.tilePattern: unknown scan mode "%s"\n', obj.mosaic.scanmode)
        end
        return
    end


    %Check that none of these will produce out of bounds motions
    msg='';
   if ~isempty(obj.parent) && isa(obj.parent,'BT') && isvalid(obj.parent)

        if min(tilePosArray(:,1)) < obj.parent.xAxis.getMinPos
            msg=sprintf('%sMinimum allowed X position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, obj.parent.xAxis.getMinPos, min(tilePosArray(:,1)) );
        end
        if max(tilePosArray(:,1)) > obj.parent.xAxis.getMaxPos
            msg=sprintf('%sMaximum allowed X position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, obj.parent.xAxis.getMaxPos, max(tilePosArray(:,1)) );
        end

        if min(tilePosArray(:,2)) < obj.parent.yAxis.getMinPos
            msg=sprintf('%sMinimum allowed Y position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, obj.parent.yAxis.getMinPos, min(tilePosArray(:,2)) );
        end
        if max(tilePosArray(:,2)) > obj.parent.yAxis.getMaxPos
            msg=sprintf('%sMaximum allowed Y position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, obj.parent.yAxis.getMinPos, max(tilePosArray(:,2)) );
        end
    else

        msg=fprintf('No valid BT object connected to recipe class. Can not generate tile pattern\n');

    end


    if ~isempty(msg)
        fprintf('\n** ERROR:\n%sNot returning any tile positions. Try repositioning your sample.\n',msg)
        tilePosArray=[];
        tileIndexArray=[];
    end



    function [tilePosArray,tileIndexArray] = generateTileGrid(obj)
        % Generate a grid of tiles in the correct order for sampling the specimen
        % in an "S"

        fov_x_MM = obj.ScannerSettings.FOV_alongColsinMicrons/1E3;
        fov_y_MM = obj.ScannerSettings.FOV_alongRowsinMicrons/1E3;

        % First column is the image obj.NumTiles.X and second is the image obj.NumTiles.Y
        numY = obj.NumTiles.Y;
        numX = obj.NumTiles.X;

        if obj.verbose
            fprintf('recipe.tilePattern is making array of X=%d by Y=%d tiles. Tile FOV: %0.3f x %0.3f mm. Overlap: %0.1f%%.\n',...
                numX, numY, fov_x_MM, fov_y_MM, round(obj.mosaic.overlapProportion*100,2));
        end


        tilePosArray = zeros(numY*numX, 2);
        R=repmat(1:numY,numX,1);
        tilePosArray(:,2)=R(:);
        theseCols=1:numX;

        for ii=1:numX:size(tilePosArray,1)
            tilePosArray(ii:ii+numX-1,1)=theseCols;
            theseCols=fliplr(theseCols);
        end

        % Subtract 1 because we want offsets from zero (i.e. how much to move)
        tileIndexArray = tilePosArray; %Store the tile indexes in the grid

        tilePosArray = tilePosArray-1;

        tilePosArray(:,1) = (tilePosArray(:,1)*fov_x_MM)*(1-obj.mosaic.overlapProportion);
        tilePosArray(:,2) = (tilePosArray(:,2)*fov_y_MM)*(1-obj.mosaic.overlapProportion);

        tilePosArray = tilePosArray*-1; %because left and forward are negative and we define first position as front left
        tilePosArray(:,1) = tilePosArray(:,1)+obj.FrontLeft.X;
        tilePosArray(:,2) = tilePosArray(:,2)+obj.FrontLeft.Y;



    function [tilePosArray,tileIndexArray] = generateRibbonPattern(obj)
        % Generate an array of ribbon coordinates to control the stage scanning

        fov_x_MM = obj.ScannerSettings.FOV_alongColsinMicrons/1E3;
        pixelSizeAlongScanLine = obj.ScannerSettings.micronsPerPixel_cols;

        fov_y_MM = obj.mosaic.sampleSize.Y; %Maybe this a good starting point 

        % First column is the image obj.NumTiles.X and second is the image obj.NumTiles.Y
        numY = obj.NumTiles.Y;  %The NumTiles class knows to return 1 in event of ribbon scanning
        numX = obj.NumTiles.X;

        if obj.verbose
            fprintf('recipe.tilePattern is making array of X=%d by Y=%d tiles. Tile FOV: %0.3f x %0.3f mm. Overlap: %0.1f%%.\n',...
                numX, numY, fov_x_MM, fov_y_MM, round(obj.mosaic.overlapProportion*100,2));
        end

        tilePosArray = zeros(numY*numX, 2);
        R=repmat(1:numY,numX,1);
        tilePosArray(:,2)=R(:);
        theseCols=1:numX;

        for ii=1:numX:size(tilePosArray,1)
            tilePosArray(ii:ii+numX-1,1)=theseCols;
            theseCols=fliplr(theseCols);
        end

        % Subtract 1 because we want offsets from zero (i.e. how much to move)
        tileIndexArray = tilePosArray; %Store the tile indexes in the grid

        tilePosArray = tilePosArray-1;

        tilePosArray(:,1) = (tilePosArray(:,1)*fov_x_MM)*(1-obj.mosaic.overlapProportion);

        %For Y we alternate 0 and the opposite side of the sample
        yPos = repmat([0;fov_y_MM], ceil(size(tilePosArray,1)/2), 1);
        tilePosArray(:,2) = yPos(1:size(tilePosArray,1));

        tilePosArray = tilePosArray*-1; %because left and forward are negative and we define first position as front left
        tilePosArray(:,1) = tilePosArray(:,1)+obj.FrontLeft.X;
        tilePosArray(:,2) = tilePosArray(:,2)+obj.FrontLeft.Y;

