classdef TileStepSize < handle
    % TileStepSize
    % 
    % Used to created a dependent property with two field in the recipe class
    % This class is incorporated as a property into the recipe class. It serves
    % no use outside of this context


    properties (Hidden)
        recipe
    end

    properties (Dependent)
        X=0 % Which the user will see as recipe.TileStepSize.X
        Y=0 % Which the user will see as recipe.TileStepSize.Y
    end


    methods
        function obj = TileStepSize(thisRecipe)
            % TileStepSize - calculate tile step size from recipe and scanner
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
            obj.recipe.tilePattern(true); %refresh everything
            fov_x_MM = obj.recipe.ScannerSettings.FOV_alongColsinMicrons/1E3; % also appears in recipe.tilePattern
            X = round(fov_x_MM * (1-obj.recipe.mosaic.overlapProportion),4);
        end

        function Y = get.Y(obj)
            % Return Y step size
            if ~obj.isReadyToCalcProperties
                Y=0;
                return
            end
            obj.recipe.tilePattern(true); %refresh everything
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
