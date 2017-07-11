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
    end

    properties (Dependent)
        X=0 % Which the user will see as recipe.NumTiles.X in the recipe class
        Y=0 % Which the user will see as recipe.NumTiles.Y in the recipe class
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
            % Return X step size
            if ~obj.isReadyToCalcProperties
                X=0;
                return
            end
            obj.recordScannerSettings; % Re-reads the scanner settings from SIBT and stores in the recipe file
            fov_x_MM = obj.recipe.ScannerSettings.FOV_alongColsinMicrons/1E3; % also appears in recipe.tilePattern
            X = round(fov_x_MM * (1-obj.recipe.mosaic.overlapProportion),4);
        end

        function Y = get.Y(obj)
            % Return Y step size
            if ~obj.isReadyToCalcProperties
                Y=0;
                return
            end
            obj.recordScannerSettings; % Re-reads the scanner settings from SIBT and stores in the recipe file
            fov_y_MM = obj.recipe.ScannerSettings.FOV_alongRowsinMicrons/1E3; % also appears in recipe.tilePattern
            y = round(fov_y_MM * (1-obj.recipe.mosaic.overlapProportion),4);
        end

    end % Methods

    methods (Hidden)
        function isReady = isReadyToCalcProperties(obj)
            % Return true if we are able to calculate the step size without crashing
            isReady=false;
            if ~isempty(obj.recipe.parent) && isvalid(obj.recipe.parent)
                isReady=true;
            end
        end
    end % Hidden methods

end %class
