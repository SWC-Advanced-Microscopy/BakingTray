function stopAllAxes(obj,~,~)
    % Stop all motion axes when the user presses the stop button
    %
    %Do in try/catch so that if one fails the others still have a chance to stop
    %TODO: this is very rough and ready. 

    if obj.model.isSlicing
        obj.model.abortSlicing
        return
    end

    msg='GUI received an indicator that the %s axis failed to stop or failed to respond to the stop command.\n';
    try
        if ~obj.model.stopZ
            fprintf(msg,'Z')
        end
    catch ME 
        %pass
    end

    try
        if ~obj.model.stopXY;
            fprintf(msg,'XY')
        end
    catch ME 
        %pass
    end

    %Force update of positions to screen (TODO: HORRIBLE)
    pos=obj.model.getXYpos;
    pos=obj.model.getZpos;
end %stopAllAxes