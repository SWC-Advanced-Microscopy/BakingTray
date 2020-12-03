function [cuttingPossible,msg] = checkIfCuttingIsPossible(obj)
    % Check if cutting possible 
    %
    % [cuttingPossible,msg] = BT.checkIfCuttingIsPossible(obj)
    %
    % Purpose
    % This method determines whether it is possible to begin cutting. 
    % e.g. It will not proceed if the X position is beyond the cut position, 
    % this would indicate that the user began a cut after an abort but before
    % returning the sample to the correct side of the blade.
    % and conncted, etc. 
    % 
    % Behavior
    % The method returns true if cutting is possible and false otherwise.
    % If it returns false and a second output argument is requested then 
    % this is a string that decribes why acquisition can not proceed. This 
    % string can be sent to a warning dialog box, etc, if there is a GUI. 



    msg='';

    % An acquisition must not already be in progress
    if obj.isSlicing
        msg=sprintf('%sCutting is already in progress\n',msg);
    end


    % We need a recipe connected
    if ~obj.isRecipeConnected
        msg=sprintf('%sNo recipe.\n',msg);
    end

    %Check the axes are conncted
    if ~obj.isXaxisConnected
        msg=sprintf('%sNo xAxis is connected.\n',msg);
    end
    if ~obj.isYaxisConnected
        msg=sprintf('%sNo yAxis is connected.\n',msg);
    end
    if ~obj.isZaxisConnected
        if obj.isRecipeConnected && obj.recipe.mosaic.numSections>1
            msg=sprintf('%sNo zAxis is connected.\n',msg);
        end
    end

    %Naturally we need a cutter
    if ~obj.isCutterConnected
        if obj.isRecipeConnected && obj.recipe.mosaic.numSections>1
            msg=sprintf('%sNo cutter is connected.\n',msg);
        end
    end


    %Do we have enough travel to make the cut itself?
    if obj.recipe.SYSTEM.cutterSide == 1
        if (obj.recipe.CuttingStartPoint.X + obj.recipe.mosaic.cutSize) > obj.xAxis.attachedStage.maxPos
            msg=sprintf('%sCutting %d mm will lead to an out of bounds stage position. Reduce cut size and try again.\n', ...
                msg, obj.recipe.mosaic.cutSize);
        end
    elseif obj.recipe.SYSTEM.cutterSide == -1
        if (obj.recipe.CuttingStartPoint.X - obj.recipe.mosaic.cutSize) > obj.xAxis.attachedStage.minPos
            msg=sprintf('%sCutting %d mm will lead to an out of bounds stage position. Reduce cut size and try again.\n', ...
                msg, obj.recipe.mosaic.cutSize);
        end
    end    



    % Ensure we have enough travel on the Z-stage to acquire all the sections
    if obj.isRecipeConnected && obj.isZaxisConnected
        distanceAvailable = obj.zAxis.getMaxPos - obj.zAxis.axisPosition;  %more positive is a more raised Z platform
        distanceRequested = obj.recipe.mosaic.numSections * obj.recipe.mosaic.sliceThickness;

        if distanceRequested>distanceAvailable
            numSlicesPossible = floor(distanceAvailable/obj.recipe.mosaic.sliceThickness)-1;
            fprintf(['\nRequested %d slices: this is %0.2f mm of tissue but only %0.2f mm is possible.\n',...
                'You can safely cut a maximum of %d slices.\n',...
                'Change your settings or sample position and try again.\n\n'], ...
             obj.recipe.mosaic.numSections,...
             distanceRequested, ...
             distanceAvailable,...
             numSlicesPossible);
        end
    end





    % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
    %Set the cuttingPossible boolean based on whether a message exists
    if isempty(msg)
        cuttingPossible=true;
    else
        cuttingPossible=false;
    end


    %Print the message to screen if the user requested no output arguments. 
    if cuttingPossible==false && nargout<2
        fprintf(msg)
    end

