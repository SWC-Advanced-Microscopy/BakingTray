function finished = sliceSample(obj,sliceThickness,cuttingSpeed)
    % Perform the cutting sequence
    % 
    % Purpose
    % This method moves to the cutting start point and initiates a cut. 
    % It uses the following parameters to know how to cut:
    %
    % obj.recipe.CuttingStartPoint .X and .Y
    % obj.recipe.mosaic.cuttingSpeed = mm/s
    % obj.recipe.mosaic.cutSize = mm %how far to cut. Include "overhang" to beyond block
    % obj.recipe.mosaic.sliceThickness = mm 
    % obj.recipe.SLICER.approachSpeed = mm/s
    % obj.recipe.SLICER.postCutDelay= seconds %Time to wait for slice to settle (slice dance occurs during the middle of this period)
    % obj.recipe.SLICER.vibrateRate - the commanded vibrate speed
    % obj.recipe.SLICER.postCutVibrate - the vibrate speed after the cut is complete. It will vibrate at this speed during the post-cut delay
    %
    %
    % Inputs (optional)
    % sliceThickness - if supplied, the value in recipe is not used and this is used instead. 
    % cuttingSpeed - if supplied, the value in recipe is not used and this is used instead. 
    %
    %
    % Outputs
    % finished : true/false depending on whether or not it ran to the end

    finished=false;
    obj.isSlicing=true;
    if isempty(obj.cutter)
        fprintf('Can not cut. No cutter connected\n')
        return
    end

    if nargin<2
        sliceThickness=obj.recipe.mosaic.sliceThickness;
    end

    if nargin<3
        cuttingSpeed=obj.recipe.mosaic.cuttingSpeed;
    end

    verbose=false; % Enable for debugging messages

    %Record in the recipe what are the values we are going to cut at. See the main recipe class help text. 
    obj.recipe.lastSliceThickness=sliceThickness;
    obj.recipe.lastCuttingSpeed=cuttingSpeed;


    % Ensure that the abort flag is false. If this is is ever true, 
    % the slice sequence will not proceed, but go directly to the cleanup function. 
    % The motion back to the start position will not be executed in the cleanup function. 
    obj.abortSlice=false;


    % Log initial (current) position and velocity settings
    [state.xInit,state.yInit] = obj.getXYpos;
    if verbose
        fprintf('Position before cutting: x=%0.2f y=%0.2f\n',...
            state.xInit, state.yInit)
    end

    %Record the default move speed
    moveStepSpeed = obj.recipe.SYSTEM.xySpeed;

    %Define a cleanup object in case the user does a ctrl-c and we end up with the 
    %stages having peculiar speed settings, etc
    tidyUp = onCleanup(@() cleanupSlicer(obj,state));

    if isempty(obj.recipe)
        obj.logMessage(inputname(1),dbstack,7,'No recipe attached to BakingTray. Can not cut.')
        obj.isSlicing=false;
        return
    end

    %Check that cutting start point contains reasonable values
    cuttingStartPoint = obj.recipe.CuttingStartPoint;
    if isempty(cuttingStartPoint.X) || isempty(cuttingStartPoint.Y)
        obj.logMessage(inputname(1),dbstack,6,'obj.recipe.cuttingStartPoint is empty. NOT CUTTING')
        obj.isSlicing=false;
        return 
    end

    obj.logMessage(inputname(1),dbstack,5,'Start cutting cycle')

    % Move Z stage up by the thickness of one slice
    obj.moveZby(sliceThickness)
    if obj.abortSlice
        return
    end

    obj.logMessage(inputname(1),dbstack,3,sprintf('Initial position - X:%0.3f Y:%0.3f',state.xInit,state.yInit))

    % Move to the cutting start point at obj.recipe.SLICER.approachSpeed
    msg=sprintf('moving to cut start point - X:%0.3f Y:%0.3f', cuttingStartPoint.X, cuttingStartPoint.Y);
    obj.logMessage(inputname(1),dbstack,4,msg)
    obj.setXvelocity(obj.recipe.SLICER.approachSpeed);
    obj.setYvelocity(obj.recipe.SLICER.approachSpeed);
    obj.moveXYto(cuttingStartPoint.X, cuttingStartPoint.Y,1);

    if obj.abortSlice
        return
    end


    pause(1) % a second before carrying on

    % start cutter and verify that it started
    obj.logMessage(inputname(1),dbstack,4,'Starting to cut')

    obj.cutter.startVibrate(obj.recipe.SLICER.vibrateRate);

    % progress a distance of obj.recipe.mosaic.cutSize mm at a speed of obj.recipe.SLICER.cuttingSpeed
    obj.setXvelocity(cuttingSpeed);
    cuttingMove=abs(obj.recipe.mosaic.cutSize)*obj.recipe.SYSTEM.cutterSide;

    obj.moveXby(cuttingMove); %Start cutting and return (don't block)
    pause(0.05)

    targetPos = obj.getXpos + cuttingMove; % Where the cutting move should finish

    while 1 %Blocking loop until we have reached the cut end position
       if ~obj.xAxis.isMoving % Uses the controller API routine (if availble)
           break
       end
       % Some stages are sensitive and the vibratome motion causes them to 
       % think the stage has not settled. So we add the following
       % statements to catch this
       if obj.recipe.SYSTEM.cutterSide==1 && obj.getXpos >= targetPos
           disp('ABORT CUT: we are at the cutting end point and this was not caught by the controller API command')
            obj.xAxis.stopAxis;
           break
       elseif obj.recipe.SYSTEM.cutterSide==-1 && obj.getXpos <= targetPos
           obj.xAxis.stopAxis;
           break
       end
       
       % To honour abort command 
       if obj.abortSlice
           return
       end
       pause(0.025)
    end

    if obj.abortSlice
        return
    end

    obj.logMessage(inputname(1),dbstack,4,'Waiting for slice to settle')

    %Vibrate slower. The stop vibrate command is in the cleanup function
    obj.cutter.startVibrate(obj.recipe.SLICER.postCutVibrate); 

    % Optionally push away the slice in X (can rip agar block off slide if blade isn't through)
    if obj.cutter.kickOffSection
        obj.setXvelocity(moveStepSpeed); %a faster speed
        obj.moveXYby(3.5*obj.recipe.SYSTEM.cutterSide,0,1); %move forwards fast by 7 mm
    end

    %Move a little faster to dislodge the slice (TODO: these values will depend on acceleration)
    obj.setYvelocity(30);

    %Wait and try to dislodge slice
    pause(obj.recipe.SLICER.postCutDelay/2)

    % initiate post-cut slice-removal dance
    swipeSize = 4;
    obj.moveXYby(0,swipeSize, 1, 0.3,1); %swipe (with 1 second time-out)
    if obj.abortSlice
        return
    end

    for ii=1:2
        swipeSize = swipeSize*-1;
        obj.moveXYby(0,swipeSize*2, 1, 0.3, 1); %swipe (with 1 second time-out)
        if obj.abortSlice
            return
        end
    end

    %Reset speeds of stages to what they were originally    
    obj.setYvelocity(moveStepSpeed);
    obj.setXvelocity(moveStepSpeed);

    finalWait=obj.recipe.SLICER.postCutDelay/2;
    obj.logMessage(inputname(1),dbstack,2,sprintf('Waiting %0.2f seconds',finalWait))
    pause(finalWait)

    finished=true;

    if nargout>0
        varargout{1}=finished;
    end
end


function cleanupSlicer(obj,state)
    verbose=false; % Enable for debugging messages
    obj.logMessage(inputname(1),dbstack,2,'Entering cleanUpSlicer')

    %Stop vibrating
    obj.cutter.stopVibrate;

    obj.stopXY; %Stop in case the cutting motion is currently taking place. Nothing happens otherwise.

    % Return slowly to initial position 
    if ~obj.abortSlice
        obj.setXvelocity(obj.recipe.SLICER.approachSpeed);
        obj.setYvelocity(obj.recipe.SLICER.approachSpeed);
        if verbose
            fprintf('Moving back to x=%0.2f and y=%0.2f\n', ...
                state.xInit, state.yInit)
        end
        obj.moveXYto(state.xInit,state.yInit,1); %blocking so control returns only once the process is finished
    end

    % Return to initial speed
    obj.setXvelocity(obj.recipe.SYSTEM.xySpeed);
    obj.setYvelocity(obj.recipe.SYSTEM.xySpeed);

    %Reset flags
    obj.abortSlice=false;
    obj.isSlicing=false;

    obj.getXYpos; %Refreshes the currentPosition properties on the stages
    obj.logMessage(inputname(1),dbstack,5,'Finish cutting cycle');
end
