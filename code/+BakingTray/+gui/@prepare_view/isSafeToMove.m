function [isSafeToMove,msg]=isSafeToMove(obj,axisToCheckIfMoving)
    % Confirm if it is safe for the prepare view to move an axis
    %
    % function [isSafeToMove,msg] = BakingTray.gui.prepare_view.isSafeToMove(obj,axisToCheckIfMoving)
    %
    % If supplied with no input args, returns false only if the system is cutting.
    % If supplied with two input args, the second is a linearstage class from one axis. 
    % If this reports it's moving, the method returns false. Otherwise true.
    %
    % If msg is also returned then no warning dialog is popped up and we instead write to the command line. 

    isSafeToMove=false;
    msg='';
    if obj.model.isSlicing
        msg=sprintf('System is slicing. Can not move.\n');
    elseif nargin>1 && axisToCheckIfMoving.isMoving
        msg=sprintf('Axis is already moving. Can not move.\n');
    end

    if isempty(msg)
        isSafeToMove=true;
    else
        if nargin>1
            fprintf(msg);
        else
            warndlg(msg,'')
        end
    end

end %safeToMove
