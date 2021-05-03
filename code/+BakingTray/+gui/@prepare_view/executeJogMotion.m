function executeJogMotion(obj,event,~)
    % Execute a jog motion on a single axis. 
    % Extracts the name of the axis and the direction to move from the tag string. 
    %
    % function BT.executeJogMotion(obj,event,~)

    %Executes a jog motion 
    jogType=strsplit(event.Tag,'||');
    motionSize=jogType{1};
    motionDirection=jogType{2};

    %Figure out which axis to move, which direction, and by how much

    if strcmp(motionDirection,'up') || strcmp(motionDirection,'down')
        %Z axis
        thisJogSize=obj.zJogSizes;
        jogAxis=obj.model.zAxis;
            if strcmp(motionDirection,'up')
                motionDirection=1;
            else
                motionDirection=-1;
            end
    else
        %X or Y axes
        thisJogSize=obj.xyJogSizes;
        if strcmp(motionDirection,'left') || strcmp(motionDirection,'right')
            jogAxis=obj.model.xAxis;
        elseif strcmp(motionDirection,'towards') || strcmp(motionDirection,'away')
            jogAxis=obj.model.yAxis;
        end
        if strcmp(motionDirection,'right') ||  strcmp(motionDirection,'away')
            motionDirection=1;
        elseif strcmp(motionDirection,'left') ||  strcmp(motionDirection,'towards')
            motionDirection=-1;
        end
    end

    %Now we know the axis, don't move if not safe to do so
    [isSafe,msg]=obj.isSafeToMove(jogAxis); %second output suppresses the pop-up and writes to command line instead
    if ~isSafe
        return
    end

    stepSize = thisJogSize.(motionSize); %Step size in mm

    if ~jogAxis.relativeMove(stepSize*motionDirection)
        fprintf('Jog reports that it failed\n')
    end

    % Block whilst axis moves then read position. Ensure there is a minimum timeout between motion
    % commands to keep things sane
    minTimeOut = 0.25; % seconds
    timeSoFar = tic; % We will subtract the time it takes to move from the min timeout
    while jogAxis.isMoving
        pause(0.05)
    end

    % Stores new stage position in the stage currentPosition property, which triggers
    % the prepare_view GUI to update.
    jogAxis.axisPosition;

    % Pause if needed
    timeElapsed = toc(timeSoFar);
    pause(minTimeOut - timeElapsed) % Handles negative numbers gracefully

end
