function [tilePosArray,tileIndexArray] = tilePattern(obj,quiet,returnEvenIfOutOfBounds,ROIparams)
    % Calculate a tile grid for imaging. The imaging will proceed in an "S" over the sample.
    %
    % function [tilePosArray,tileIndexArray] = recipe.tilePattern(obj,quiet,returnEvenIfOutOfBounds)
    %
    %
    % Purpose
    % Calculate the position grid needed to tile a sample of a given size, with a given
    % field of view, and a given overlap between adjacent tiles. TileStepSize and 
    % NumTiles are dependent properties of recipe and are based on external helper classes.
    %
    %
    % Inputs
    % quiet - false by default
    % returnEvenIfOutOfBounds - false by default
    % ROIparams - empty by default. If present, it should be a structure defining the 
    %             ROI front/left position and size in tiles. The structure can have a 
    %             length of more than 1. example:
    % ROIparams.numTiles.X - an integer number of tiles
    % ROIparams.numTiles.Y - an integer number of tiles
    % ROIparams.frontLeftPixel.X - location of the front/left corner pixel of this ROI along image rows
    % ROIparams.frontLeftPixel.Y - location of the front/left corner pixel of this ROI along image columns
    % ROIparams.frontLeftStageMM.X - location of the front/left-most corner stage position of all ROIs -- x stage position in mm
    % ROIparams.frontLeftStageMM.Y - location of the front/left-most corner stage position of all ROIs -- y stage position in mm
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

    if nargin<3
        % This is set to true by recipe.setFrontLeftFromVentralMidLine
        % Nothing else should be setting this to true
        returnEvenIfOutOfBounds=false;
    end

    if nargin<4
        ROIparams=[];
    end

    % Declare empty output variables in case of error and to allow concatenation of multiple ROIs
    tilePosArray=[];
    tileIndexArray=[];

    % Call recipe.recordScannerSettings to populate the imaging parameter fields such as 
    % recipe.ScannerSettings, recipe.VoxelSize, etc. We then use these values
    % to build up the tile scan pattern.
    success = obj.recordScannerSettings;

    if ~success
        if ~quiet
            fprintf('ERROR in recipe.tilePattern: no scanner connected. Please connect a scanner to BakingTray\n')
        end
        return
    end

    if isempty(ROIparams) && isempty(obj.FrontLeft.X) || isempty(obj.FrontLeft.Y)
        if ~quiet
            fprintf('ERROR in recipe.tilePattern: no front-left position defined. Can not calculate tile pattern.\n')
        end
        return
    end


    %Generate the tile array
    if isempty(ROIparams)
        [tilePosArray,tileIndexArray] = generateTileGrid(obj);
    else
        % The loop allows for multiple bounding boxes
        for ii = 1:length(ROIparams)
            [t_tilePosArray,t_tileIndexArray] = generateTileGrid(obj,ROIparams(ii));
            tilePosArray = [tilePosArray; t_tilePosArray];
            tileIndexArray = [tileIndexArray; t_tileIndexArray];
        end
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
        if ~quiet
            fprintf('\n** ERROR:\n%sNot returning any tile positions. Try repositioning your sample.\n',msg)
            fprintf('Attempted to make a tile pattern from %0.2f to %0.2f in X and %0.2f to %0.2f in Y\n',...
                 min(tilePosArray(:,1)), max(tilePosArray(:,1)), min(tilePosArray(:,2)), max(tilePosArray(:,2)) )
        end
        % Make certain the outputs are empty
        if ~returnEvenIfOutOfBounds
            tilePosArray=[];
            tileIndexArray=[];
        end
    end

end % tilePattern


    %% LOCAL FUNCTIONS FOLLOW

    function [tilePosArray,tileIndexArray] = generateTileGrid(obj,ROIparams)
        % Generate a grid of tiles in the correct order for sampling the specimen
        % in an "S". The tile grid is based on the following variables:
        %   * The field of view of the microscope
        %   * How much overlap we want between adjacent tiles
        %   * The desired width and length of the bounding box in mm
        %

        verbose=true;

        % Obtain the microscope FOV
        fov_x_MM = obj.ScannerSettings.FOV_alongColsinMicrons/1E3;
        fov_y_MM = obj.ScannerSettings.FOV_alongRowsinMicrons/1E3;

        if nargin<2 || isempty(ROIparams)
            % Get the number of tiles in X and Y required to tile the grid. NumTiles is a class that can return this
            ROIparams.numTiles.X = obj.NumTiles.X;
            ROIparams.numTiles.Y = obj.NumTiles.Y;
            ROIparams.frontLeftMM.X = obj.FrontLeft.X;
            ROIparams.frontLeftMM.Y = obj.FrontLeft.Y;
        else
            ROI_FL = [ROIparams.frontLeftPixel.X,ROIparams.frontLeftPixel.Y];
            ROI_frontLeft_in_MM = obj.parent.convertImageCoordsToStagePosition(ROI_FL,ROIparams.frontLeftStageMM);
            ROIparams.frontLeftMM.X = ROI_frontLeft_in_MM(1);
            ROIparams.frontLeftMM.Y = ROI_frontLeft_in_MM(2);

            if verbose
                fprintf('recipe.tilePattern > generateTileGrid produces a ROI with a front/left stage coord: x=%0.2f, y=%0.2f\n', ...
                    ROIparams.frontLeftMM.X, ROIparams.frontLeftMM.Y)
            end
        end


        if obj.verbose
            fprintf('recipe.tilePattern is making array of X=%d by Y=%d tiles. Tile FOV: %0.3f x %0.3f mm. Overlap: %0.1f%%.\n',...
                ROIparams.numTiles.X, ROIparams.numTiles.Y, fov_x_MM, fov_y_MM, round(obj.mosaic.overlapProportion*100,2));
        end

        % Pre-allocate the array of tile positions. Initially this will contain the index of each tile in the
        % grid. i.e. how many tile positions away from the origin in X and Y each tile should be. Later this 
        % will be converted to a location in mm. 
        tilePosArray = zeros(ROIparams.numTiles.Y*ROIparams.numTiles.X, 2);

        % Fill in column 2, which will be the locations for the Y stage
        R=repmat(1:ROIparams.numTiles.Y,ROIparams.numTiles.X,1);
        tilePosArray(:,2)=R(:);

        theseCols=1:ROIparams.numTiles.X; % The tile index locations along the X axis

        for ii=1:ROIparams.numTiles.X:size(tilePosArray,1)
            tilePosArray(ii:ii+ROIparams.numTiles.X-1,1)=theseCols; %Insert X stage positions into the array
            theseCols=fliplr(theseCols); %Flip the X locations so the stage will "S" over the sample
        end

        % Subtract 1 because we want offsets from zero (i.e. how much to move)
        tileIndexArray = tilePosArray; %Store the tile indexes in the grid
        tilePosArray = tilePosArray-1;

        % Convert tile index values into positions in mm based on the FOV
        tilePosArray(:,1) = (tilePosArray(:,1)*fov_x_MM) * (1-obj.mosaic.overlapProportion);
        tilePosArray(:,2) = (tilePosArray(:,2)*fov_y_MM) * (1-obj.mosaic.overlapProportion);

        % Apply an offset to the pattern so that it's positioned correctly in X/Y
        tilePosArray = tilePosArray * -1; %because left and forward are negative and we define first position as front left
        tilePosArray(:,1) = tilePosArray(:,1) + ROIparams.frontLeftMM.X;
        tilePosArray(:,2) = tilePosArray(:,2) + ROIparams.frontLeftMM.Y;

        if ~isempty(obj.mosaic.tilesToRemove)
            tilePosArray(obj.mosaic.tilesToRemove,:)=[];
            tileIndexArray(obj.mosaic.tilesToRemove,:)=[];
        end
    end
