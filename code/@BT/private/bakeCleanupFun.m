function bakeCleanupFun(obj)
    %Perform clean-up operations once bake completes. 

    %So we don't turn off laser if acqusition failed right away
    if obj.currentTilePosition==1
        fprintf(['Acquisition seems to have failed right away since BT.bake has finished with currentTilePosition==1.\n',...
            'Not turning off laser.\n'])
        obj.leaveLaserOn=true; 
    end

    %TODO: these three lines also appear in BakingTray.gui.acquisition_view
    obj.detachLogObject; % Run this again here (as well as in acq loop, above, just in case)
    obj.scanner.disarmScanner;
    obj.scanner.averageSavedFrames=true; % Just in case a testing session was done before
    obj.acquisitionInProgress=false;
    obj.acquisitionState='idle';    
    obj.sectionCompletionTimes=[]; %clear the array of completion times. 

    obj.lastTilePos.X=0;
    obj.lastTilePos.Y=0;


    if obj.isLaserConnected && ~obj.leaveLaserOn
        % If the laser was tasked to turn off and we've done more than 25 sections then it's very likely
        % this was a full-on acquisition and nobody is present at the machine. If so, we send a Slack message 
        % to indicate that acquisition is done.
        minSections=25;
        if obj.currentSectionNumber>minSections
            obj.slack(sprintf('Acquisition of %s finished after %d sections.', ...
                obj.recipe.sample.ID, obj.currentSectionNumber))
        else
            fprintf('Not sending Slack message because only %d sections completed, which is less than threshold of %d\n',...
                obj.currentSectionNumber, minSections)
        end

        obj.acqLogWriteLine(sprintf('Attempting to turn off laser\n'));
        success=obj.laser.turnOff;
        if ~success
            obj.acqLogWriteLine(sprintf('Laser turn off command reports it did not work\n'));
        else
            if ~isa(obj.laser,'dummyLaser')
                pause(10) %it takes a little while for the laser to turn off
            end
            msg=sprintf('Laser reports it turned off: %s\n',obj.laser.returnLaserStats);
            if obj.currentSectionNumber>minSections
                obj.slack(msg)
            end
            obj.acqLogWriteLine(msg);
        end
    else 
        % So we can report to screen if this is reset
        % We do the reset otherwise a subsequent run will have the laser on when it completes 
        % (but this means we have to set this each time)
        fprintf(['Acquisition finished and Laser will NOT be turned off.\n',...
            'BT.bake is setting the "leaveLaserOn" flag to false: laser will attempt to turn off next time.\n'])
        obj.acqLogWriteLine(sprintf('Laser will not be turned off because the leaveLaserOn flag is set to true\n'));
        obj.leaveLaserOn=false;
    end

    %Reset these flags or the acquisition will not complete next time
    obj.abortAfterSectionComplete=false;
    obj.abortAcqNow=false;


    % Must run this last since turning off the PMTs sometimes causes a crash
    obj.scanner.tearDown

    % Move the X/Y stage to a nice finish postion, ready for next sample
    obj.moveXYto(obj.recipe.FrontLeft.X,0)

    % In a crash we can sometimes still be indicating that the system is cutting. So stop this
    if obj.isSlicing
        fprintf('BT.bake notices that BakingTray thinks it is slicing. Likely it is not and this is a bug. Resetting this flag.\n')
        obj.isSlicing=false;
    end

    % Reset
    obj.currentSectionNumber=1;
    obj.autoROI=[]; % Ensure these stats are never applied to another session

    % Return to manual ROI mode
    obj.recipe.mosaic.scanmode = 'tiled: manual ROI';

    % Ensure all tiles will be imaged next time around:
    obj.recipe.mosaic.tilesToRemove=[];

end %bakeCleanupFun
