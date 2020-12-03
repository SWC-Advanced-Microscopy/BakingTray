classdef NumTiles < handle
    % NumTiles - Calculate the number of tiles in the sample for the recipe class
    %
    % Used to create a dependent property with two fields in the recipe class.
    % Here it calculates the number of tiles in X and Y given the overlap and
    % the requested sample size. This class is incorporated as a property into 
    % the recipe class. It serves no use outside of this context
    %
    % The code is written with the following assumption:
    % The fast scan axis (or the columns of the image) extend along the direction of the X stage (which moves left/right WRT to the user standing in front of the system)
    % The slow scan axis (or the rows of the image) extend along the direction of the Y stage (which moves front/back WRT to the user standing in front of the system)
    % These conventions will be most important if we are are working with non-square images, as failing to adhere to the conventions will lead to images that can't be
    % stitched.

    properties (Hidden)
        recipe
        roundThresh=0.15 %When rounding the number of required tiles, exceeding this fraction of a tile will lead 
                         %to a ceil but staying within it will round down. i.e. if roundThresh equals 0.15, then
                         %6.13 tiles is rounded down to 6 tiles but 6.25 is rounded up to 7 tiles. 
    end

    properties (Dependent)
        X=0 % Which the user will see as recipe.NumTiles.X in the recipe class
        Y=0 % Which the user will see as recipe.NumTiles.Y in the recipe class
        tilesPerPlane  % Which the user will see as recipe.NumTiles.tilesPerPlane in the recipe class (returns a struct)
    end


    methods
        function obj = NumTiles(thisRecipe)
            % NumTiles - calculate number of tiles in grid from recipe and scanner
            obj.recipe=thisRecipe;
        end

        function delete(obj)
            obj.recipe=[];
        end

        function X = get.X(obj)
            % Return the number of tiles in X per optical plane
            if ~obj.isReadyToCalcProperties
                X=0;
                return
            end
            obj.recipe.recordScannerSettings; % Re-reads the scanner settings (e.g. from SIBT) and stores in the recipe file
            fov_x_MM = obj.recipe.ScannerSettings.FOV_alongColsinMicrons/1E3; % also appears in recipe.tilePattern
            X = obj.roundTiles(obj.recipe.mosaic.sampleSize.X / ((1-obj.recipe.mosaic.overlapProportion) * fov_x_MM) );
        end %get.X

        function Y = get.Y(obj)
            % Return the number of tiles in Y per optical planeY
            if ~obj.isReadyToCalcProperties
                Y=0;
                return
            end
            obj.recipe.recordScannerSettings; % Re-reads the scanner settings from SIBT and stores in the recipe file
            fov_y_MM = obj.recipe.ScannerSettings.FOV_alongRowsinMicrons/1E3; % also appears in recipe.tilePattern
            Y = obj.roundTiles(obj.recipe.mosaic.sampleSize.Y / ((1-obj.recipe.mosaic.overlapProportion) * fov_y_MM) );
        end %get.Y

        function N = get.tilesPerPlane(obj)
            % Return the total number of tiles per optical plane
            if ~obj.isReadyToCalcProperties
                N=0;
                return
            end
            obj.recipe.recordScannerSettings; % Re-reads the scanner settings from SIBT and stores in the recipe file

            fov_y_MM = obj.recipe.ScannerSettings.FOV_alongRowsinMicrons/1E3; % also appears in recipe.tilePattern
            N.Y = obj.roundTiles(obj.recipe.mosaic.sampleSize.Y / ((1-obj.recipe.mosaic.overlapProportion) * fov_y_MM) );

            fov_x_MM = obj.recipe.ScannerSettings.FOV_alongColsinMicrons/1E3; % also appears in recipe.tilePattern
            N.X = obj.roundTiles(obj.recipe.mosaic.sampleSize.X / ((1-obj.recipe.mosaic.overlapProportion) * fov_x_MM) );
            N.total = N.X * N.Y;
        end %get.tilesPerPlane

    end % Methods

    methods (Hidden)
        function isReady = isReadyToCalcProperties(obj)
            % Return true if we are able to calculate the step size without crashing
            isReady=false;
            if ~isempty(obj.recipe.parent) && isvalid(obj.recipe.parent) &&  obj.recipe.parent.isScannerConnected
                isReady=true;
            end
        end %isReadyToCalcProperties

        function out = roundTiles(obj,tilesToRound)
            if mod(tilesToRound,1)>obj.roundThresh
                out = ceil(tilesToRound);
            else
                out = floor(tilesToRound);
            end
        end %roundTiles
    end % Hidden methods

end %class
