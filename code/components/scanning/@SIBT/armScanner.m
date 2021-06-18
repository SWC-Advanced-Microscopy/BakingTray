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
            trigLine='PF1';
        case 'linear'
            trigLine='PFI0';
    end

    if ~strcmp(obj.hC.hScan2D.trigAcqInTerm, trigLine)
      % The try/catch is here because at the moment I can not
      % find a way of identifying whether we have a vDAQ.
      % vDAQ does not have PFI lines and so errors. TODO
      try
          obj.hC.hScan2D.trigAcqInTerm=trigLine;
      catch ME
          if strcmp(ME.message, 'Invalid channel ID.')
              obj.hC.hScan2D.trigAcqInTerm='D0.0';
          end
        end
    end

    obj.enableArmedListeners

    % The string "msg" will contain any messages we wish to display to the user as part of the confirmation box.
    msg = '';

    if any(obj.hC.hChannels.channelSubtractOffset)
        obj.hC.hChannels.channelSubtractOffset(:)=0;  % Disable offset subtraction
    end

    % Ensure the offset is auto-read so we can use this value later
    if ~obj.hC.hScan2D.channelsAutoReadOffsets
        obj.hC.hScan2D.channelsAutoReadOffsets=true;
    end

    msg = sprintf('%sDisabled offset subtraction.\n',msg);


    % Set up ScanImage z-stacks
    obj.applyZstackSettingsFromRecipe % Prepare ScanImage for doing z-stacks

    % Set the system to display just the first depth in ScanImage.
    % Should run a little faster this way, especially if we have
    % multiple channels being displayed.
    if obj.hC.hStackManager.numSlices>1 && isempty(obj.hC.hDisplay.selectedZs)
        fprintf('Displaying only first depth in ScanImage for speed reasons.\n');
            obj.hC.hDisplay.volumeDisplayStyle='Current';
            obj.hC.hDisplay.selectedZs=0;
    end

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

    obj.leaveResonantScannerOn

    fprintf('Armed scanner: %s\n', datestr(now))

    % Disable PMT auto-on, as this can cause rare and random MATLAB hard-crashes. Maybe this only
    % happens with USB DAQs, but we want to avoid any possibility that it happens at all.
    obj.hC.hPmts.autoPower(:) = 0;
end %armScanner
