function sectionInd = bake(obj,varargin)
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
    % Outputs
    % sectionInd - the index of the main bake loop. If the loop didn't start, this will be 0.
    %
    % Rob Campbell - Basel, Feb, 2017
    %
    % See also BT.runTileScan


    sectionInd = 0; 
    obj.currentTilePosition=1; % so if there is an error before the main loop we don't turn off the laser.
    if ~obj.isScannerConnected 
        fprintf('No scanner connected.\n')
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
    [acqPossible,msg]=obj.checkIfAcquisitionIsPossible(true); %true to indicate this is a bake
    if ~acqPossible
        fprintf(msg)
        warndlg(msg,'Acquisition failed to start');
        return
    end

    %Define an anonymous function to nicely print the current time
    currentTimeStr = @() datestr(now,'yyyy/mm/dd HH:MM:SS');

    fprintf('Setting up acquisition of sample %s\n',obj.recipe.sample.ID)


    % Remove any attached file logger objects. We will add one per physical section.
    % Reset properties in preparation for acquisition
    obj.detachLogObject
    obj.currentTileSavePath=[];
    obj.sectionCompletionTimes=[];
    obj.acquisitionInProgress=true;
    obj.abortAcqNow=false; % This and the following property can't be on before we've even started
    obj.abortAfterSectionComplete=false; 

    % Assign cleanup function, which is in private directory
    tidy = onCleanup(@() bakeCleanupFun(obj)); 

    %----------------------------------------------------------------------------------------


    fprintf('\n\n\n ------>>  Starting To Bake  <<------ \n\n\n')



    obj.acqLogWriteLine( sprintf('%s -- STARTING NEW ACQUISITION\n',currentTimeStr() ) )

    % Report to screen and the log file how much disk space is currently available
    msg = obj.reportAcquisitionSize;
    obj.acqLogWriteLine(msg)

    if ~isempty(obj.laser)
        obj.acqLogWriteLine(sprintf('Using laser: %s\n', obj.laser.readLaserID))
    end

    % Print the version number and name of the scanning software 
    obj.acqLogWriteLine(sprintf('Acquiring with: %s\n', obj.scanner.getVersion))

    try
        G=BakingTray.utils.getGitInfo;
        obj.acqLogWriteLine(sprintf('Using BakingTray version %s from branch %s\n', G.hash, G.branch))
    catch
        obj.acqLogWriteLine('Failed to extract git commit info for logging\n')
    end


    % Set the watchdog timer on the laser to 40 minutes. The laser
    % will switch off after this time if it heard nothing back from bake. 
    % e.g. if the computer reboots spontaneously, the laser will turn off 40 minutes later. 
    if ~isempty(obj.laser)
        wDogSeconds = 40*60;
        obj.laser.setWatchDogTimer(wDogSeconds);
        obj.acqLogWriteLine(sprintf('Setting laser watchdog timer to %d seconds\n', wDogSeconds))
    end


    %Log the current time to the recipe
    obj.recipe.Acquisition.acqStartTime = currentTimeStr();



    % auto-ROI stuff if the user has selected this. Note that after the following if statement
    % we have populated obj.currentTilePattern. This myuste be done before arming the scanner, as scanner arming 
    % requires us to know how many tiles will be imaged. 
    if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
        obj.currentSectionNumber = obj.recipe.mosaic.sectionStartNum;  % TODO -- not tested with auto-ROI resume
        fprintf('Bake is in auto-ROI mode. Setting currentSectionNumber to 1 and getting first ROIs:\n')
        obj.populateCurrentTilePattern;  %this calls BT.populateCurrentTilePattern
        fprintf('Starting auto-ROI acquisition with a grid of %d tiles\n', ...
            length(obj.currentTilePattern))
        fprintf('\nDONE\n')
    elseif strcmp(obj.recipe.mosaic.scanmode,'tiled: manual ROI')
        obj.populateCurrentTilePattern;
    end


    %loop and tile scan
    for sectionInd=1:obj.recipe.mosaic.numSections
        obj.currentSectionNumber = sectionInd+obj.recipe.mosaic.sectionStartNum-1; % This is the current physical section

        fprintf('\n\n%s\n * Section %d\n\n',repmat('-',1,70),obj.currentSectionNumber) % Print a line across the CLI


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
        % TIFF header. (TODO)
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
        % We will use this later to decide whether to cut. This test asks if the positionArray is complete 
        % so we don't cut if tiles are missing. We test here because the position array is modified before
        % cutting can happen.
        if obj.tilesRemaining==0
            sectionCompleted=true;
        else
            sectionCompleted=false;
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

        % Save the downsampled tile cache to the rawData directory if this is appropriate
        if obj.keepAllDownSampledTiles
            fprintf('Saving the tile cache from the last section\n')
            tileCache = obj.allDownsampledTilesOneSection;
            cacheFname = fullfile(obj.currentTileSavePath,'tileCache.mat');
            save(cacheFname,'tileCache')
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
                fprintf('Saving ScanImage settings file to %s\n', saveSettingsTo)
                save(fullfile(saveSettingsTo,'scanSettings.mat'), 'scanSettings')
            end
        end

        if obj.abortAcqNow
            fprintf('BT.bake: BT.abortAcq is true. Stopping acquisition.\n')
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
        chanDisp=obj.scanner.getChannelsToDisplay;
        if length(chanDisp)>1 && isa(obj.scanner,'SIBT')
            fprintf('Setting chan display to %d only in BT.bake\n', chanDisp(end))
            obj.scanner.setChannelsToDisplay = chanDisp(end);
        end


        % If the user is running auto-ROI, we now re-calculated the bounding boxes. The method call
        % to getNextROIs does this and also updates currentTilePattern.
        if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
            % Save the pStack file (TODO -- should we leave this here?)
            pStack_fname = fullfile(obj.currentTileSavePath, 'sectionPreview.mat');
            sectionPreview = obj.autoROI.previewImages;
            sectionPreview = rmfield(sectionPreview,'recipe');
            save(pStack_fname,'sectionPreview')
            success = obj.getNextROIs;


            if ~success
                % Bail out gracefully if no tissue was found
                msg = sprintf('Found no tissue in Section %d during Bake. Quitting acquisition.', ...
                    obj.currentSectionNumber);
                obj.acqLogWriteLine(sprintf('%s -- %s\n', currentTimeStr(), msg))
                fprintf('\n*** %s ***\n\n',msg)
                obj.slack(msg)
                return
            end

            % Save to disk the stats for the auto-ROI
            autoROI_fname = fullfile(obj.pathToSectionDirs,obj.autoROIstats_fname);
            autoROI_stats = obj.autoROI.stats;
            save(autoROI_fname,'autoROI_stats')
        else
            % Wipe the last two columns of the position array. These save the actual stage 
            % positions. This is necessary for the acquisition resume to work properly.
            obj.positionArray(:,end-1:end)=nan;
        end


        % Cut the sample if necessary
        if sectionCompleted
            %Mark the section as complete
            fname=fullfile(obj.currentTileSavePath,'COMPLETED');
            fid=fopen(fname,'w+');
            fprintf(fid,'COMPLETED');
            fclose(fid);

            obj.acqLogWriteLine(sprintf('%s -- acquired %d tile positions in %s\n',...
            currentTimeStr(), floor(obj.currentTilePosition-1), prettyTime((now-startAcq)*24*60^2)) );

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

