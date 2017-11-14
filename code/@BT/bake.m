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


    obj.currentTilePosition=1; % so if there is an error before the main loop we don't turn off the laser.
    if ~obj.isScannerConnected 
        fprintf('No scanner connected.\n')
        return
    end

    if ~isa(obj.scanner,'SIBT')
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

    fprintf('Starting data acquisition\n')
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
    %
    % TODO: for this to work, we must ensure that the return info method is doing something.
    %       users need to be careful here if writing code for different lasers.
    if ~isempty(obj.laser)
        wDogSeconds = 40*60;
        obj.laser.setWatchDogTimer(wDogSeconds);
        obj.acqLogWriteLine(sprintf('Setting laser watchdog timer to %d seconds\n', wDogSeconds))
    end


    %pre-allocate the tile buffer
    obj.preAllocateTileBuffer
    
    obj.sectionCompletionTimes=[]; %Clear the array of completion times

    %Log the current time to the recipe
    obj.recipe.Acquisition.acqStartTime = currentTimeStr();
    obj.acquisitionInProgress=true;
    obj.abortAfterSectionComplete=false; %This can't be on before we've even started

    %Do ribbon-specific stuff (e.g. work out where the z-planes should be)
    if strcmp(obj.recipe.mosaic.scanmode,'ribbon')
        obj.scanner.moveFastZTo(0)
        nOptPlanes = obj.recipe.mosaic.numOpticalPlanes;
        opticalRibbonPlanesToImage = (0:nOptPlanes-1) * round(obj.recipe.VoxelSize.Z,1);
    else %We are not ribbon-scanning
        opticalRibbonPlanesToImage=1; %This needs to be 1 if we are doing tile scanning
    end


    %loop and tile scan
    for ii=1:obj.recipe.mosaic.numSections

        % Ensure hBT exists in the base workspace
        assignin('base','hBT',obj)

        obj.currentSectionNumber = ii+obj.recipe.mosaic.sectionStartNum-1; % This is the current physical section
        if obj.currentSectionNumber<0
            fprintf('WARNING: BT.bake is setting the current section number to less than 0\n')
        end

        obj.acqLogWriteLine(sprintf('%s -- STARTING section number %d (%d of %d) at z=%0.4f in directory %s\n',...
            currentTimeStr() ,obj.currentSectionNumber, ii, obj.recipe.mosaic.numSections, obj.getZpos, ...
            strrep(obj.currentTileSavePath,'\','\\') ))
        startAcq=now;

        if ~isempty(obj.laser)
            % Record laser status before section
            obj.acqLogWriteLine(sprintf('laser status: %s\n', obj.laser.returnLaserStats)) 
        end


        for tDepthInd = 1:length(opticalRibbonPlanesToImage) %One pass through this loop if tile scanning
            obj.currentOpticalSectionNumber = tDepthInd; %Does nothing if we're not ribbon-scanning

            if obj.saveToDisk
                if ~obj.defineSavePath % Define directories into which we will save data. Create if needed.
                    % (Detailed warnings are produced by defineSavePath method)
                    disp('Acquisition stopped: save path not defined');
                    return 
                end
                obj.scanner.setUpTileSaving; % This method is aware of the requirements of ribbon vs tile scanning

                %Add logger object to the above directory
                logFilePath = fullfile(obj.currentTileSavePath,'acquisition_log.txt');
                obj.attachLogObject(bkFileLogger(logFilePath))
            end % if obj.saveToDisk

            % Move the PIFOC if needed
            if strcmp(obj.recipe.mosaic.scanmode,'ribbon')
                obj.scanner.moveFastZTo(opticalRibbonPlanesToImage(obj.currentOpticalSectionNumber));
            end

            if ~obj.scanner.armScanner;
                disp('FAILED TO START -- COULD NOT ARM SCANNER')
                return
            end

            % ===> Now the scanning runs <===
            if ~obj.runTileScan
                return
            end

        end % for tDepthInd ...


        %Return the PIFOC to zero if needed
        if strcmp(obj.recipe.mosaic.scanmode,'ribbon')
            obj.currentOpticalSectionNumber=1;
            obj.scanner.moveFastZTo(opticalRibbonPlanesToImage(obj.currentOpticalSectionNumber));
        end


        % If the laser is off-line for some reason (e.g. lack of modelock, we quit
        % so we don't cut and the sample is safe. 
        if obj.isLaserConnected
            [isReady,msg]=obj.laser.isReady;
            if ~isReady
                %TODO: this should be able to send a Slack message or e-mail to the user
                msg = sprintf('*** STOPPING ACQUISITION DUE TO LASER: %s ***\n',msg);
                fprintf(msg)
                obj.acqLogWriteLine(msg)
                return
            end
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

            if ii<obj.recipe.mosaic.numSections || obj.sliceLastSection
                obj.sliceSample;
            end
        else
            fprintf('Still waiting for %d tiles. Not cutting. Aborting.\n',obj.tilesRemaining)
            obj.scanner.abortScanning;
            return
        end

        obj.detachLogObject %Close the log file that writes to the section directory


        % Now the recipe has been modified (at the start of BakingTray.bake) we can write the full thing to disk
        if ii==1
            obj.recipe.writeFullRecipeForAcquisition(obj.sampleSavePath);
        end

        if ~isempty(obj.laser)
            % Record laser status after section
            obj.acqLogWriteLine(sprintf('laser status: %s\n', obj.laser.returnLaserStats)) 
        end

        elapsedTimeInSeconds=(now-startAcq)*24*60^2;
        obj.acqLogWriteLine(sprintf('%s -- FINISHED section number %d, section completed in %s\n',...
            currentTimeStr() ,obj.currentSectionNumber, prettyTime(elapsedTimeInSeconds) ));

        obj.sectionCompletionTimes(end+1)=elapsedTimeInSeconds;

        % If this is the first pass through the loop and we're using ScanImage, dump
        % the settings to a file. TODO: eventually we need to decide what to do with other
        % scan systems and abstract this code. 
        if ii==1 && strcmp(obj.scanner.scannerID,'ScanImage via SIBT')
            d=dir(fullfile(obj.currentTileSavePath,'*.tif'));
            if ~isempty(d)
                tmp_fname = fullfile(obj.currentTileSavePath,d(end).name);
                TMP=scanimage.util.opentif(tmp_fname);
                scanSettings = TMP.SI;
                saveSettingsTo = fileparts(fileparts(obj.currentTileSavePath));
                save(fullfile(saveSettingsTo,'scanSettings.mat'), 'scanSettings')
            end
        end

        if obj.abortAfterSectionComplete
            %TODO: we could have a GUI come up that allows the user to choose if they want this happen.
            obj.acqLogWriteLine(sprintf('%s -- BT.bake received "abortAfterSectionComplete". Not turning off the laser.\n',currentTimeStr() ));
            obj.leaveLaserOn=true;
            break
        end

    end % for ii=1:obj.recipe.mosaic.numSections


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
    %Perform clean up functions

    %So we don't turn off laser if acqusition failed right away
    if obj.currentTilePosition==1
        fprintf(['Acquisition seems to have failed right away since BT.bake has finished with currentTilePosition==1.\n',...
            'Not turning off laser.\n'])
        obj.leaveLaserOn=true; 
    end

    %TODO: these three lines also appear in BakingTray.gui.acquisition_view
    obj.detachLogObject; % Run this again here (as well as in acq loop, above, just in case)
    obj.scanner.disarmScanner;
    obj.acquisitionInProgress=false;
    obj.sectionCompletionTimes=[]; %clear the array of completion times. 

    obj.lastTilePos.X=0;
    obj.lastTilePos.Y=0;


    if obj.isLaserConnected & ~obj.leaveLaserOn
        obj.acqLogWriteLine(sprintf('Attempting to turn off laser\n'));
        success=obj.laser.turnOff;
        if ~success
            obj.acqLogWriteLine(sprintf('Laser turn off command reports it did not work\n'));
        else
            pause(10) %it takes a little while for the laser to turn off
            msg=sprintf('Laser reports it turned off: %s\n',obj.laser.returnLaserStats);
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

    obj.abortAfterSectionComplete=false; %Reset this flag or the acquisition will not complete next time

    if strcmp(obj.recipe.mosaic.scanmode,'ribbon')
        % Ensure we are back to square pixels (in case of prior riboon scan)
        obj.scanner.hC.hRoiManager.forceSquarePixels=true;
        obj.scanner.allowNonSquarePixels=false;
        obj.scanner.hC.hRoiManager.scanAngleMultiplierFast=0.75; % TODO -- BAD HARD-CODED HACK!
        obj.scanner.moveFastZTo(0)
    end

    % Must run this last since turning off the PMTs sometimes causes a crash
    obj.scanner.tearDown

end %bakeCleanupFun
