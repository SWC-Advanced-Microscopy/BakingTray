function abortSlicing(obj)
    % Abort slicing of a section initiated by BT.sliceSample
    %
    % function BT.abortSlicing
    %
    % Purpose
    % Instantly aborts the cutting sequence: stops the motion of all three 
    % axes and re-sets the stage speeds to their default values.
    %

    obj.abortSlice=true; %BT.sliceSample will look here to decide what to do when the stages stop

    try
        obj.stopZ;
    catch
        %pass
    end

    try
        obj.stopXY;
    catch
        %pass
    end


end
