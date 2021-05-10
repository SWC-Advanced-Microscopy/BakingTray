function resetBladeIfNeeded(obj)

    % Move to the cutting start point if sample is beyond blade.
    % This causes the blade to always return to this position when trimming 
    % and it avoids user confusion in cases such as an abort of the cutting 
    % that then leads to the blade returning to a location above the sample

    startPoint = obj.model.recipe.CuttingStartPoint.X; %Cutting start point
    xPos = obj.model.getXpos;

    
    if obj.model.recipe.SYSTEM.cutterSide == 1
        % Blade to the right as looking at the rig
        if xPos > startPoint
          obj.model.moveXYto(obj.model.recipe.CuttingStartPoint.X-0.5,0,true)
        end

    elseif obj.model.recipe.SYSTEM.cutterSide == -1
        if xPos < startPoint
         obj.model.moveXYto(obj.model.recipe.CuttingStartPoint.X+0.5,0,true)
        end
    end
