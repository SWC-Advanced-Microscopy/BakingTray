function checkIfAcquisitionIsPossible(obj,~,~)
    % Callback function that checks if it will be possible to acquire data based on the current recipe settings
    %
    % Purpose
    % Checks if the acquisition is possible and writes true or false to the acquisitionPossible accordingly.


    if isempty(obj.FrontLeft.X) || isempty(obj.FrontLeft.Y) || ...
        isempty(obj.CuttingStartPoint.X) || isempty(obj.CuttingStartPoint.Y) || ...
        isempty(obj.mosaic.sampleSize.X) || isempty(obj.mosaic.sampleSize.Y)

        obj.acquisitionPossible=false;
        return
    end

    if isempty(obj.sample.ID)
        obj.acquisitionPossible=false;
        return
    end

    % The front left position needs to be *at least* the thickness of a cut from the 
    % blade plus half the X width of the specimen. This doesn't even account for
    % the agar, etc. So it's a very relaxed criterion. 
    if isnan(obj.CuttingStartPoint.X)
        % blade position not set if it's a Nan and system will not cut
        obj.acquisitionPossible=false;
        return
    end

    if obj.SYSTEM.cutterSide==1
        if (obj.FrontLeft.X-obj.mosaic.sampleSize.X) < obj.CuttingStartPoint.X
            obj.acquisitionPossible=true;
        else
            fprintf('recipe.checkIfAcquisitionIsPossible thinks the blade may hit the sample during acquisition\n')
            obj.acquisitionPossible=false;
        end
    elseif obj.SYSTEM.cutterSide==-1
        fprintf('WARNING: recipe class may not be certain blade will not hit sample during acquisition\n')
        % This scenario has never been tested with physical hardware
        if obj.FrontLeft.X>obj.CuttingStartPoint.X
            obj.acquisitionPossible=true;
        else
            obj.acquisitionPossible=false;
        end
    end

end % checkIfAcquisitionIsPossible
