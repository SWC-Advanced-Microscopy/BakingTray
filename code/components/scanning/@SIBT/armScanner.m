function [success,msg] = armScanner(obj)
    %Arm scanner and tell it to acquire a fixed number of frames (as defined below)
    success=false;
    if isempty(obj.parent) || ~obj.parent.isRecipeConnected
        obj.logMessage(inputname(1) ,dbstack,7,'SIBT is not attached to a BT object with a recipe')
        return
    end

    % We'll need to enable external triggering on the correct terminal line. 
    % Safest to instruct ScanImage of this each time. 
    switch obj.scannerType
        case 'resonant'
            %To make it possible to enable the external trigger. PFI0 is reserved for resonant scanning
            trigLine='PFI1';
        case 'linear'
            trigLine='PFI0';
    end

    if ~strcmp(obj.hC.hScan2D.trigAcqInTerm, trigLine)
        obj.hC.hScan2D.trigAcqInTerm=trigLine;
    end

    obj.enableArmedListeners

    % The string "msg" will contain any messages we wish to display to the user as part of the confirmation box.
    msg = '';

    if any(obj.hC.hChannels.channelSubtractOffset)
        obj.hC.hChannels.channelSubtractOffset(:)=0;   % Disable offset subtraction
    end

    % Ensure the offset is auto-read so we can use this value later
    if ~obj.hC.hScan2D.channelsAutoReadOffsets
        obj.hC.hScan2D.channelsAutoReadOffsets=true;
    end

    msg = sprintf('%sDisabled offset subtraction.\n',msg);


    % Set up ScanImage according the type of scan pattern we will use
    switch obj.parent.recipe.mosaic.scanmode
    case 'tile'
        obj.applyZstackSettingsFromRecipe % Prepare ScanImage for doing z-stacks
    case 'ribbon'
        R = obj.returnScanSettings;
        xResInMM = R.micronsPerPixel_cols * 1E-3;

        if isempty(obj.parent.currentTilePattern)
            obj.parent.currentTilePattern = obj.parent.recipe.tilePattern;
        end

        yRange = range(obj.parent.currentTilePattern(:,2));

        numLines = round(yRange/xResInMM);

        obj.allowNonSquarePixels=true;
        if obj.hC.hRoiManager.forceSquarePixels==true
            obj.hC.hRoiManager.forceSquarePixels=false;
        end

        %Set linesPerFrame for ribbon scanning
        linesPerFrame = round(numLines*1.05);
        if mod(linesPerFrame,2)~=0 %Ensure an odd number of lines
            linesPerFrame=linesPerFrame+1;
        end

        if obj.hC.hRoiManager.linesPerFrame ~= linesPerFrame
            obj.hC.hRoiManager.linesPerFrame = linesPerFrame;
        end

        %Disable Z-stack
        obj.hC.hStackManager.numSlices = 1;
        obj.hC.hStackManager.stackZStepSize = 0;
    end

    % Set the system to display just the first depth in ScanImage. 
    % Should run a little faster this way, especially if we have 
    % multiple channels being displayed.
    if obj.hC.hStackManager.numSlices>1 && isempty(obj.hC.hDisplay.selectedZs)
        fprintf('Displaying only first depth in ScanImage for speed reasons.\n');
            obj.hC.hDisplay.volumeDisplayStyle='Current';
            obj.hC.hDisplay.selectedZs=0;
    end

    % obj.hC.hScan2D.mdfData.shutterIDs=[]; %Disable shutters %TODO -- assume control over shutter
    %If any of these fail, we leave the function gracefully

    try
        %Set the number of acquisitions. This will cause the acquisitions edit box in ScanImage to update.
        %The number of acquisitions is equal to the number of x/y positions that need to be visited
        obj.hC.acqsPerLoop=obj.parent.recipe.numTilesInOpticalSection;
        obj.hC.extTrigEnable=1;
        %Put it into acquisition mode but it won't proceed because it's waiting for a trigger
        obj.hC.startLoop;
    catch ME1
        rethrow(ME1)
        return
    end
    success=true;

    if strcmpi(obj.scannerType, 'resonant')
        % This will only be turned off again when the teardown method is run
        obj.hC.hScan2D.keepResonantScannerOn=obj.leaveResonantScannerOnWhenArmed;
    end

    fprintf('Armed scanner: %s\n', datestr(now))
end %armScanner
