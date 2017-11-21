function moveFastZTo(obj,targetPositionInMicrons)
    % Move the fast Z to an absolute position
    %
    % SIBT.moveFasZTo(targetPositionInMicrons)
    %
    % No feedback is provided. 


    obj.hC.hFastZ.positionTarget = targetPositionInMicrons;
