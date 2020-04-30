function runSuccess = runTileScan(obj,boundingBoxDetails)
    % This method inititiates the acquisition of a tile scan for one section
    %
    % function runSuccess = BT.runTileScan(obj)
    % 
    % Purpose
    % The method moves the sample to the front/left position, initialises some variables
    % then initiates the scan cycle. This method is called by BT.bake.

    runSuccess=false;

    % TODO --- should the auto-ROI be passed in this way? Could all be local to here and not need .bake to say what to do
    if nargin<2
        boundingBoxDetails=[];
    end

    % Create the position array
    [pos,indexes]=obj.recipe.tilePattern(false,false,boundingBoxDetails);
    obj.positionArray = [indexes,pos,nan(size(pos))]; %We will store the stage locations here as we go

    % Move to the front left position
    obj.setXYvelocity(obj.recipe.SYSTEM.xySpeed)
    obj.toFrontLeft;

    if ~isa(obj.xAxis,'dummy_linearcontroller')
        pause(1) %Wait a second for stuff to settle just in case (this may be a fast move)
    end

    % Log this first location to disk, otherwise it won't be recorded.
    obj.currentTilePosition=1;
    obj.logPositionToPositionArray;


    % PLACEHOLDER: in case we need specific actions for acq type. TODO!
    switch obj.recipe.mosaic.scanmode
        case 'tiled: manual ROI'
            % pass
        case 'tiled: auto-ROI'
            % pass
    end

    %TODO: ensure the acquisition is stopped before we proceed

    % Concept
    % We can't run the tile scan in an explicit for loop because we need to trigger the next frame
    % *immediately* after the acquisition of the current frame. So this needs to be an event
    % triggered by a listener that's monitoring the notifier which fires when the frame has been
    % acquired. So the events that handle the next frame will be triggered by the callback function
    % we attach to frameAcquired in ScanImage. We just have to initiate the first frame here, then
    % the acquisition process will continue until all frames have been acquired. 

    startTime=now;

    % Instruct the scanner to initiate the tile scan. This may simply involving issuing a trigger if tile scanning
    obj.scanner.initiateTileScan; %acquires a stack and triggers the scanner (e.g. ScanImage) to acquire the rest of the stacks

    %block until done
    while 1
        if ~obj.scanner.isAcquiring
            break
        end
        pause(0.25)
    end


    %Ensure we are back at normal motion speed
    obj.setXYvelocity(obj.recipe.SYSTEM.xySpeed) 

    % Report the total time
    totalTime = now-startTime;
    totalTime = totalTime*24*60^2;

    switch obj.recipe.mosaic.scanmode
    case 'tiled: manual ROI'
        nTilesToAcquire = obj.recipe.numTilesInPhysicalSection;
    case 'tiled: auto-ROI'
        % TODO -- UNKNOWN?
        nTilesToAcquire = obj.recipe.numTilesInPhysicalSection;
    end

    fprintf('\nFinished %d tile positions. Acquired %d images per channel (%d x %d x %d) in %0.1f seconds (averaging %0.2f s per tile)\n\n', ...
        floor(obj.currentTilePosition), nTilesToAcquire, obj.recipe.NumTiles.X, obj.recipe.NumTiles.Y, ...
        obj.recipe.mosaic.numOpticalPlanes, totalTime, totalTime/(obj.currentTilePosition))
    runSuccess=true;
