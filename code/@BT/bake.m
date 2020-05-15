function bake(obj,varargin)
    % Runs an automated anatomy acquisition using the currently attached parameter file
    %
    % function BT.bake('Param1',val1,'Param2',val2,...)
    %
    %
    % Inputs (optional param/val pairs)
    % 'leaveLaserOn' - If true, the laser is not switched off when acquisition finishes. 
    %                  This setting can also be supplied by setting BT.leaveLaserOn. If 
    %                  not supplied, this built-in value is used. 
    %
    % 'sliceLastSection' - If false, the last section of the whole acquisition is not cut 
    %                      off the block. This setting can also be supplied by setting 
    %                      BT.leaveLaserOn. If not supplied, this built-in value is used. 
    %
    %
    %
    %
    % Rob Campbell - Basel, Feb, 2017
    %
    % See also BT.runTileScan


    obj.currentTilePosition=1; % so if there is an error before the main loop we don't turn off the laser.
    if ~obj.isScannerConnected 
        fprintf('No scanner connected.\n')
        return
    end

    if ~isa(obj.scanner,'SIBT') && ~isa(obj.scanner,'dummyScanner')
        fprintf('Only acquisition with ScanImage supported at the moment.\n')
        return
    end

    %Parse the optional input arguments
    params = inputParser;
    params.CaseSensitive = false;

    params.addParameter('leaveLaserOn', obj.leaveLaserOn, @(x) islogical(x) || x==1 || x==0)
    params.addParameter('sliceLastSection', obj.sliceLastSection, @(x) islogical(x) || x==1 || x==0)
    params.parse(varargin{:});

    obj.leaveLaserOn=params.Results.leaveLaserOn;
    obj.sliceLastSection=params.Results.sliceLastSection;


    % ----------------------------------------------------------------------------
    %Check whether the acquisition is likely to fail in some way
    [acqPossible,msg]=obj.checkIfAcquisitionIsPossible;
    if ~acqPossible
        fprintf(msg)
        warndlg(msg,'Acquisition failed to start');
        return
    end


    % Report to screen and the log file how much disk space is currently available
    acqInGB = obj.recipe.estimatedSizeOnDisk;
    fprintf('Acquisition will take up %0.2g GB of disk space\n', acqInGB)
    volumeToWrite = strsplit(obj.sampleSavePath,filesep);
    volumeToWrite = volumeToWrite{1};
    out = BakingTray.utils.returnDiskSpace(volumeToWrite);
    msg = sprintf('Writing to volume %s which has %d/%d GB free\n', ...
        volumeToWrite, round(out.freeGB), round(out.totalGB));
    fprintf(msg)
    obj.acqLogWriteLine(msg)


    %Define an anonymous function to nicely print the current time
    currentTimeStr = @() datestr(now,'yyyy/mm/dd HH:MM:SS');


    fprintf('Setting up acquisition of sample %s\n',obj.recipe.sample.ID)


    %Remove any attached file logger objects. We will add one per physical section
    obj.detachLogObject


    %----------------------------------------------------------------------------------------

    fprintf('\n\n\n ------>>  Starting To Bake  <<------ \n\n\n')
    obj.currentTileSavePath=[];
    tidy = onCleanup(@() bakeCleanupFun(obj));

    obj.acqLogWriteLine( sprintf('%s -- STARTING NEW ACQUISITION\n',currentTimeStr() ) )
    if ~isempty(obj.laser)
        obj.acqLogWriteLine(sprintf('Using laser: %s\n', obj.laser.readLaserID))
    end

    % Print the version number and name of the scanning software 
    obj.acqLogWriteLine(sprintf('Acquiring with: %s\n', obj.scanner.getVersion))


    % Report to the acquisition log whether we will attempt to turn off the laser at the end
    if obj.leaveLaserOn
        obj.acqLogWriteLine('Laser set to stay on at the end of acquisition\n')
    else
        obj.acqLogWriteLine('Laser set to switch off at the end of acquisition\n')
    end

    % Report to the acquisition log whether we will attempt to slice the last section
    if obj.sliceLastSection
        obj.acqLogWriteLine('BakingTray will slice the final imaged section off the block\n')
    else
        obj.acqLogWriteLine('BakingTray will NOT slice the final imaged section off the block\n')
    end


    % Set the watchdog timer on the laser to 40 minutes. The laser
    % will switch off after this time if it heard nothing back from bake. 
    % e.g. if the computer reboots spontaneously, the laser will turn off 40 minutes later. 
    if ~isempty(obj.laser)
        wDogSeconds = 40*60;
        obj.laser.setWatchDogTimer(wDogSeconds);
        obj.acqLogWriteLine(sprintf('Setting laser watchdog timer to %d seconds\n', wDogSeconds))
    end


    obj.sectionCompletionTimes=[]; %Clear the array of completion times

    %Log the current time to the recipe
    obj.recipe.Acquisition.acqStartTime = currentTimeStr();
    obj.acquisitionInProgress=true;
    obj.abortAfterSectionComplete=false; %This can't be on before we've even started



    % auto-ROI stuff if the user has selected this. Note that after the following if statement
    % we have populated obj.currentTilePattern. This myuste be done before arming the scanner, as scanner arming 
    % requires us to know how many tiles will be imaged. 
    if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
        obj.currentSectionNumber = obj.recipe.mosaic.sectionStartNum;  % TODO -- not tested with auto-ROI resume
        fprintf('Bake is in auto-ROI mode. Setting currentSectionNumber to 1 and getting first ROIs:\n')
        obj.getNextROIs
        fprintf('\nDONE\n')
    elseif strcmp(obj.recipe.mosaic.scanmode,'tiled: manual ROI')
        obj.currentTilePattern=obj.recipe.tilePattern;
    end



        % TODO -- debugging horrible thing for auto-ROI dev
        doViewDebug=false;
        if obj.importLastFrames && false
            % Overlay tile grid for next section
            hBTview=evalin('base','hBTview');
            if isvalid(hBTview.view_acquire)
                XL_orig = hBTview.view_acquire.imageAxes.XLim;
                YL_orig = hBTview.view_acquire.imageAxes.YLim;
                doViewDebug=true;
            end
        end

    %loop and tile scan
    for sectionInd=1:obj.recipe.mosaic.numSections

        fprintf('\n\n%s\n * Section %d\n\n',repmat('-',1,70),sectionInd) % Print a line across the CLI

        % Ensure hBT exists in the base workspace
        assignin('base','hBT',obj)

        obj.currentSectionNumber = sectionInd+obj.recipe.mosaic.sectionStartNum-1; % This is the current physical section
        if obj.currentSectionNumber<0
            fprintf('WARNING: BT.bake is setting the current section number to less than 0\n')
        end


        if ~obj.defineSavePath % Define directories into which we will save data. Create if needed.
            % (Detailed warnings are produced by defineSavePath method)
            disp('Acquisition stopped: save path not defined');
            return
        end



        tLine = sprintf('%s -- STARTING section number %d (%d of %d) at z=%0.4f in directory %s\n',...
            currentTimeStr() ,obj.currentSectionNumber, sectionInd, obj.recipe.mosaic.numSections, obj.getZpos, ...
            strrep(obj.currentTileSavePath,'\','\\') );
        obj.acqLogWriteLine(tLine)
        startAcq=now;

        if ~isempty(obj.laser)
            % Record laser status before section
            obj.acqLogWriteLine(sprintf('laser status: %s\n', obj.laser.returnLaserStats)) 
        end


        if obj.saveToDisk
            obj.scanner.setUpTileSaving;

            %Add logger object to the above directory
            logFilePath = fullfile(obj.currentTileSavePath,'acquisition_log.txt');
            obj.attachLogObject(bkFileLogger(logFilePath))
        end % if obj.saveToDisk

        if ~obj.scanner.armScanner
            disp('FAILED TO START -- COULD NOT ARM SCANNER')
            return
        end

        % Now the recipe has been modified (at the start of BakingTray.bake) we can write the full thing to disk
        if sectionInd==1
            obj.recipe.writeFullRecipeForAcquisition(obj.sampleSavePath);
        end

        % For syncAndCrunch to be happy we need to write the currently
        % displayed channels. A bit of hack, but it's easiest solution
        % for now. Alternative would be to have S&C rip it out of the
        % TIFF header. 
        if sectionInd==1 && strcmp(obj.scanner.scannerID,'ScanImage via SIBT')
            scanSettings.hChannels.channelDisplay = obj.scanner.hC.hChannels.channelDisplay;
            saveSettingsTo = fileparts(fileparts(obj.currentTileSavePath)); %Save to sample root directory
            save(fullfile(saveSettingsTo,'scanSettings.mat'), 'scanSettings')
        end


        %  ===> Now the scanning runs <===
        if ~obj.runTileScan
            fprintf('\n--> BT.runTileScan returned false. QUITTING BT.bake\n\n')
            return
        end
        % ===> Tile scan finished <===


        %If requested, save the current preview stack to disk
        if exist(obj.logPreviewImageDataToDir,'dir')
            try
                fname=sprintf('%s_section_%d_%s.mat', ...
                                obj.recipe.sample.ID, ...
                                obj.currentSectionNumber, ...
                                 datestr(now,'YYYY_MM_DD'));
                fname = fullfile(obj.logPreviewImageDataToDir,fname);
                fprintf('SAVING PREVIEW IMAGE TO: %s\n',fname)
                imData=obj.lastPreviewImageStack;
                save(fname,'imData')
            catch
                fprintf('Failed to save preview stack to log dir\n')
            end
        end

        % Now we save to full scan settings by stripping data from a tiff file.
        % If this is the first pass through the loop and we're using ScanImage, dump
        % the settings to a file. TODO: eventually we need to decide what to do with other
        % scan systems and abstract this code. 

        if sectionInd==1 && strcmp(obj.scanner.scannerID,'ScanImage via SIBT')
            d=dir(fullfile(obj.currentTileSavePath,'*.tif'));
            if ~isempty(d)
                tmp_fname = fullfile(obj.currentTileSavePath,d(end).name);
                TMP=scanimage.util.opentif(tmp_fname);
                scanSettings = TMP.SI;
                saveSettingsTo = fileparts(fileparts(obj.currentTileSavePath)); %Save to sample root directory
                save(fullfile(saveSettingsTo,'scanSettings.mat'), 'scanSettings')
            end
        end

        if obj.abortAcqNow
            break
        end



        % If the laser is off-line for some reason (e.g. lack of modelock, we quit
        % so we don't cut and the sample is safe.
        if obj.isLaserConnected

            [isReady,msg]=obj.laser.isReady;
            if ~isReady
                % Otherwise pause and check it's really down before carrying on
                pause(3)
                [isReady,msg]=obj.laser.isReady;
            end
            if ~isReady
                msg = sprintf('LASER NOT RUNNING (Section %d): %s\n', obj.currentSectionNumber, msg);
                obj.acqLogWriteLine(msg);
                msg = sprintf('%s\BakingTray trying to recover it.\n',msg);
                obj.slack(msg);
                obj.laser.turnOn
                pause(3)
                obj.laser.openShutter
                pause(2)
                for ii=1:15
                    if obj.laser.isReady
                        obj.acqLogWriteLine('LASER RECOVERED\n');
                        obj.slack('BakingTray managed to recover the laser.');
                        break
                    end
                    pause(10)
                end
            end
            if ~isReady
                msg = sprintf('*** STOPPING ACQUISITION DUE TO LASER: %s ***\n',msg);
                obj.slack(msg)
                fprintf(msg)
                obj.acqLogWriteLine(msg)
                return
            end
        end

        % If too many channels are being displayed, fix this before carrying on
        chanDisp=obj.scanner.channelsToDisplay;
        if length(chanDisp)>1 && isa(obj.scanner,'SIBT')
            % A bit horrible, but it will work
            obj.scanner.hC.hChannels.channelDisplay=chanDisp(end);
        end

        % Cut the sample if necessary
        if obj.tilesRemaining==0 %This test asks if the positionArray is complete so we don't cut if tiles are missing
            %Mark the section as complete
            fname=fullfile(obj.currentTileSavePath,'COMPLETED');
            fid=fopen(fname,'w+');
            fprintf(fid,'COMPLETED');
            fclose(fid);

            obj.acqLogWriteLine(sprintf('%s -- acquired %d tile positions in %s\n',...
            currentTimeStr(), obj.currentTilePosition-1, prettyTime((now-startAcq)*24*60^2)) );

            if sectionInd<obj.recipe.mosaic.numSections || obj.sliceLastSection
                %But don't slice if the user asked for an abort and sliceLastSection is false
                if obj.abortAfterSectionComplete && ~obj.sliceLastSection
                    % pass
                else
                    obj.sliceSample;
                end
            end
        else
            fprintf('Still waiting for %d tiles. Not cutting. Aborting.\n',obj.tilesRemaining)
            obj.scanner.abortScanning;
            return
        end

        % TODO -- debugging horrible thing for auto-ROI dev
        if doViewDebug && false
            fprintf('Adding grid overlays for these ROIs\n')
            % Overlay tile grid for next section
            z=obj.recipe.tilePattern(false,false,obj.autoROI.stats.roiStats(end).BoundingBoxDetails);
            hBTview.view_acquire.overlayTileGridOnImage(z)
            %hBTview.view_acquire.imageAxes.XLim=XL_orig;
            %hBTview.view_acquire.imageAxes.YLim=YL_orig;

            % plot in a separate window what autoROI should have asked for
            a=obj.autoROI;
            a.stats.roiStats = a.stats.roiStats(end);
            figure(1988)
            autoROI.plotting.showBoundingBoxesForSection(a.previewImages,a.stats)
            axis xy

            disp(' *** PRESS RETURN FOR NEXT ROIS *** '); pause % TODO - for debugging during auto-ROI dev
        end



        % If the user is running auto-ROI, we now re-calculated the bounding boxes. The method call
        % to getNextROIs does this and also updates currentTilePattern.
        if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
            obj.getNextROIs
            % Save to disk the stats for the auto-ROI
            autoROI_fname = fullfile(obj.pathToSectionDirs,obj.autoROIstats_fname);
            autoROI_stats = obj.autoROI.stats;
            save(autoROI_fname,'autoROI_stats')
        end

        % TODO -- debugging horrible thing for auto-ROI dev
        if doViewDebug
            fprintf('\n Adding grid overlays after next ROI\n')
            % Overlay tile grid for next section

            hBTview.view_acquire.overlayTileGridOnImage(obj.currentTilePattern)
            %hBTview.view_acquire.imageAxes.XLim=XL_orig;
            %hBTview.view_acquire.imageAxes.YLim=YL_orig;

            % plot in a separate window what autoROI should have asked for
            a=obj.autoROI;
            a.stats.roiStats = a.stats.roiStats(end);
            figure(1988)
            autoROI.plotting.showBoundingBoxesForSection(a.previewImages,a.stats)

            disp(' *** PRESS RETURN FOR NEXT SECTION *** '); pause % TODO - for debugging during auto-ROI dev
            hBTview.view_acquire.removeOverlays

        end

        obj.detachLogObject %Close the log file that writes to the section directory


        if ~isempty(obj.laser)
            % Record laser status after section
            obj.acqLogWriteLine(sprintf('laser status: %s\n', obj.laser.returnLaserStats)) 
        end

        elapsedTimeInSeconds=(now-startAcq)*24*60^2;
        obj.acqLogWriteLine(sprintf('%s -- FINISHED section number %d, section completed in %s\n',...
            currentTimeStr(), obj.currentSectionNumber, prettyTime(elapsedTimeInSeconds) ));

        obj.sectionCompletionTimes(end+1)=elapsedTimeInSeconds;

        if obj.abortAfterSectionComplete
            %TODO: we could have a GUI come up that allows the user to choose if they want this happen.
            obj.acqLogWriteLine(sprintf('%s -- BT.bake received "abortAfterSectionComplete". Not turning off the laser.\n',currentTimeStr() ));
            obj.leaveLaserOn=true;
            break
        end


        %%disp(' *** PRESS RETURN FOR NEXT SECTION *** '); pause

    end % for sectionInd=1:obj.recipe.mosaic.numSections


    fprintf('Finished data acquisition\n')
    if obj.scanner.isAcquiring
        msg = ('FORCING ABORT: SOMETHING WENT WRONG--too many tiles were defined for some reason or data were not acquired.');
        disp(msg)
        obj.acqLogWriteLine( sprintf('%s -- %s\n',currentTimeStr(), msg) );
        obj.scanner.abortScanning;
    end

    obj.acqLogWriteLine(sprintf('%s -- FINISHED AND COMPLETED ACQUISITION\n',currentTimeStr() ));


    %Create an empty finished file
    fid=fopen(fullfile(obj.sampleSavePath,'FINISHED'), 'w');
    fclose(fid);

end


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

end %bakeCleanupFun
