function runSuccess = runTileScan(obj)
    % This method inititiates the acquisition of a tile scan for one section
    %
    % function runSuccess = BT.runTileScan(obj)
    % 
    % Purpose
    % The method moves the sample to the front/left position, initialises some variables
    % then initiates the scan cycle. 
    
    runSuccess=false;

    
    % Create the position array
    [pos,indexes]=obj.recipe.tilePattern;
    obj.positionArray = [indexes,pos,nan(size(pos))]; %We will store the stage locations here as we go

    startTime=now;

    % Move to the front left position
    obj.setXYvelocity(obj.recipe.SYSTEM.xySpeed)
    obj.toFrontLeft;
    pause(1) %Wait a second for stuff to settle just in case (this may be a fast move)

    % Log this first location to disk, otherwise it won't be recorded.
    obj.currentTilePosition=1;
    obj.logPositionToPositionArray;

    % Set up stages for the acquisition type.
    % Also set up triggering on line 1 of the Y stage if we're doing a ribbon scan. Otherwise disable it.
    switch obj.recipe.mosaic.scanmode
    case 'tile'
        obj.yAxis.disableInMotionTrigger(1)

    case 'ribbon'
        obj.yAxis.enableInMotionTrigger(1)
        obj.setYvelocity(20) % TODO: set this according to image resolution
    end

    %TODO: ensure the acquisition is stopped before we proceed

    % Concept
    % We can't run the tile scan in an explicit for loop because we need to trigger the next frame
    % *immediately* after the acquisition of the current frame. So this needs to be an event
    % triggered by a listener that's monitoring the notifier which fires when the frame has been
    % acquired. So the events that handle the next frame will be triggered by the callback function
    % we attach to frameAcquired in ScanImage. We just have to initiate the first frame here, then
    % the acquisition process will continue until all frames have been acquired. 

    % Instruct the scanner to initiate the tile scan. This may simply involving issuing a trigger if tile scanning
    % or will initiate a motion that will itself trigger if ribbon scanning.
    obj.scanner.initiateTileScan; %acquires a stack and triggers scanimage to acquire the rest of the stacks

    %block until done
    while 1
        if ~obj.scanner.isAcquiring
            break
        end
        pause(0.25)
    end


    %Disable in-motion triggering if it was enabled
    if strcmp(obj.recipe.mosaic.scanmode,'ribbon')
        obj.yAxis.disableInMotionTrigger(1)
    end
    %Ensure we are back at normal motion speed
    obj.setXYvelocity(obj.recipe.SYSTEM.xySpeed) 

    % Report the total time
    totalTime = now-startTime;
    totalTime = totalTime*24*60^2;
    fprintf('\nFinished %d tiles (%d x %d x %d) in %0.1f seconds (%0.2f s per tile)\n\n',...
        obj.recipe.numTilesInPhysicalSection, ....
        obj.recipe.NumTiles.X, obj.recipe.NumTiles.Y, obj.recipe.mosaic.numOpticalPlanes, ...
        totalTime, totalTime/obj.recipe.numTilesInPhysicalSection)
    runSuccess=true;

