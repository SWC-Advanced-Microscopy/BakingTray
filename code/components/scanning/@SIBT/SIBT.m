classdef SIBT < scanner
%% SIBT
% BakingTray does not call ScanImage directly but goes through this glue
% object that inherits the abstract class, scanner. The SIBT concrete class 
% as a glue or bridge between ScanImage and BakingTray. This class 
% implements all the methods needed to trigger image acquisition, set the 
% power at the sample, and save images, etc. The reason for doing this is
% to provide the possibility of using a different piece of acquisition 
% software without changing any of the methods in the core BakingTray
% class or any of the GUIs. It also makes it possible to create a dummy
% scanner that serves up previously acquired data. This can be used to 
% prototype different acquisition scenarios requiring a live acquisition
% to be taking place. 
%
%

% TODO: what does  hSI.hScan2D.scannerToRefTransform do?

    properties
        % If true you get debug messages printed during scanning and when listener callbacks are hit
        verbose=false;
        settings=struct('tileRotate',-1, 'doResetTrippedPMT',0);
        leaveResonantScannerOnWhenArmed = true
    end

    properties (Hidden)
        defaultShutterIDs %The default shutter IDs used by the scanner
        maxStripe=1; %Number of channel window updates per second
        listeners={}
        armedListeners={} %These listeners are enabled only when the scanner is "armed" for acquisition
        currentTilePattern
        allowNonSquarePixels=false
        cachedChanLUT={} %Used to determine if channel look-up tables have changed
        lastSeenScanSettings = struct %A structure that stores the last seen scan setting to determine if a setting has changed
                                      %If a setting has changeded, the flipScanSettingsChanged method is run
    end

    methods %This is the main methods block. These methods are declared in the scanner abstract class

        %constructor
        function obj=SIBT(API)
            if nargin<1
                API=[];
            end
            obj.connect(API);
            obj.scannerID='ScanImage via SIBT';
        end %constructor


        %destructor
        function delete(obj)
            cellfun(@delete,obj.listeners)
            cellfun(@delete,obj.armedListeners)
            obj.hC=[];
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        function success = connect(obj,API)
            %TODO: why the hell isn't this in the constructor?
            success=false;

            if nargin<2 || isempty(API)
                scanimageObjectName='hSI';
                W = evalin('base','whos');
                SIexists = ismember(scanimageObjectName,{W.name});
                if ~SIexists
                    obj.logMessage(inputname(1),dbstack,7,'ScanImage not started. Can not connect to scanner.')
                    return
                end

                API = evalin('base',scanimageObjectName); % get hSI from the base workspace
            end

            if ~isa(API,'scanimage.SI')
                obj.logMessage(inputname(1) ,dbstack,7,'hSI is not a ScanImage object.')
                return
            end

            obj.hC=API;

            fprintf('\n\nStarting SIBT interface for ScanImage\n')

            %Log default state of settings so we return to these when disarming, as we will assume control over the shutter
            obj.defaultShutterIDs = obj.hC.hScan2D.mdfData.shutterIDs;


            % Add ScanImage-specific listeners

            obj.channelsToAcquire; %Stores the currently selected channels to save in an observable property
            % Update channels to save property whenever the user makes changes in scanImage
            obj.listeners{end+1} = addlistener(obj.hC.hChannels,'channelSave', 'PostSet', @(src,evt) obj.changeChecker(src,evt));
            obj.listeners{end+1} = addlistener(obj.hC.hChannels,'channelDisplay', 'PostSet', @(src,evt) obj.changeChecker(src,evt));

            obj.listeners{end+1} = addlistener(obj.hC, 'active', 'PostSet', @obj.isAcquiring);

            % obj.enforceSquarePixels
            %Set listeners on properties we don't want the user to change. Hitting any of these
            %will call a single method that resets all of the properties to the values we desire. 
            obj.listeners{end+1} = addlistener(obj.hC.hRoiManager, 'forceSquarePixels', 'PostSet', @obj.enforceSquarePixels);

            obj.LUTchanged
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan1LUT', 'PostSet', @obj.LUTchanged);
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan2LUT', 'PostSet', @obj.LUTchanged);
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan3LUT', 'PostSet', @obj.LUTchanged);
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan4LUT', 'PostSet', @obj.LUTchanged);


            obj.listeners{end+1}=addlistener(obj.hC.hRoiManager, 'scanZoomFactor', 'PostSet', @(src,evt) obj.changeChecker(src,evt));
            obj.listeners{end+1}=addlistener(obj.hC.hRoiManager, 'scanFrameRate',  'PostSet', @(src,evt) obj.changeChecker(src,evt));
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay, 'displayRollingAverageFactor',  'PostSet', @(src,evt) obj.changeChecker(src,evt));

            % Add "armedListeners" that are used during tiled acquisition only.
            obj.armedListeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqDone', @obj.tileAcqDone);
            obj.armedListeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqAbort', @obj.tileScanAbortedInScanImage);
            obj.disableArmedListeners % Because we only want them active when we start tile scanning

            if isfield(obj.hC.hScan2D.mdfData,'stripingMaxRate') &&  obj.hC.hScan2D.mdfData.stripingMaxRate>obj.maxStripe
                %The number of channel window updates per second
                fprintf('Restricting display stripe rate to %d Hz. This can speed up acquisition.\n',obj.maxStripe)
                obj.hC.hScan2D.mdfData.stripingMaxRate=obj.maxStripe;
            end

            obj.enforceSquarePixels
            success=true;
        end %connect


        function ready = isReady(obj)
            if isempty(obj.hC)
                ready=false;
                return
            end
            ready=strcmpi(obj.hC.acqState,'idle');
        end %isReady


        function applyZstackSettingsFromRecipe(obj)
            % applyZstackSettingsFromRecipe
            % This method is (at least for now) specific to ScanImage. 
            % Its main purpose is to set the number of planes and distance between planes.
            % It also sets the the view style to tiled. This method is called by armScanner
            % but also by external classes at certain times in order to set up the correct 
            % Z settings in ScanImage so the user can do a quick Grab and check the
            % illumination correction with depth.

            thisRecipe = obj.parent.recipe;
            if thisRecipe.mosaic.numOpticalPlanes>1
                fprintf('Setting up z-scanning with "step" waveform\n')

                % Only change settings that need changing, otherwise it's slow.
                % The following settings are fixed: they will never change
                if ~strcmp(obj.hC.hFastZ.waveformType,'step') 
                    obj.hC.hFastZ.waveformType = 'step'; %Always
                end
                if obj.hC.hFastZ.numVolumes ~= 1
                    obj.hC.hFastZ.numVolumes=1; %Always
                end
                if obj.hC.hFastZ.enable ~=1
                    obj.hC.hFastZ.enable=1;
                end
                if obj.hC.hStackManager.stackReturnHome ~= 1
                    obj.hC.hStackManager.stackReturnHome = 1;
                end

                % Now set the number of slices and the distance in z over which to image
                sliceThicknessInUM = thisRecipe.mosaic.sliceThickness*1E3;

                if obj.hC.hStackManager.numSlices ~= thisRecipe.mosaic.numOpticalPlanes;
                    obj.hC.hStackManager.numSlices = thisRecipe.mosaic.numOpticalPlanes;
                end

                if obj.hC.hStackManager.stackZStepSize ~= sliceThicknessInUM/obj.hC.hStackManager.numSlices; 
                    obj.hC.hStackManager.stackZStepSize = sliceThicknessInUM/obj.hC.hStackManager.numSlices; %Will be uniformly spaced always!
                end


                if strcmp(obj.hC.hDisplay.volumeDisplayStyle,'3D')
                    fprintf('Setting volume display style from 3D to Tiled\n')
                    obj.hC.hDisplay.volumeDisplayStyle='Tiled';
                end

            else % There is no z-stack being performed

                %Ensure we disable z-scanning if this is not being used
                obj.hC.hStackManager.numSlices = 1;
                obj.hC.hStackManager.stackZStepSize = 0;
                obj.hC.hFastZ.enable=false;
                
            end
            
            
            % Apply averaging as needed
            aveFrames = obj.hC.hDisplay.displayRollingAverageFactor;  
            if aveFrames>1
                fprintf('Setting up averaging of %d frames\n', aveFrames)
            end
            obj.hC.hScan2D.logAverageFactor = 1; % To avoid warning
            obj.hC.hStackManager.framesPerSlice = aveFrames;
            obj.hC.hScan2D.logAverageFactor = aveFrames;
            
        end % applyZstackSettingsFromRecipe

        function success = disarmScanner(obj)
            if obj.hC.active
                obj.logMessage(inputname(1),dbstack,7,'Scanner still in acquisition mode. Can not disarm.')
                success=false;
                return
            end

            obj.hC.extTrigEnable=0;
            obj.hC.hScan2D.mdfData.shutterIDs=obj.defaultShutterIDs; %re-enable shutters
            obj.disableArmedListeners;
            obj.disableTileSaving

            % Return tile display mode to settings more useful to the user
            obj.hC.hDisplay.volumeDisplayStyle='Tiled';
            obj.hC.hDisplay.selectedZs=[];

           
            success=true;
            fprintf('\nDisarmed scanner: %s\n', datestr(now))
        end %disarmScanner


        function abortScanning(obj)
            obj.hC.hCycleManager.abort;
        end


        function acquiring = isAcquiring(obj,~,~)
            %Returns true if a focus, loop, or grab is in progress even if the system is not
            %currently acquiring a frame
            if obj.verbose
                fprintf('Hit SIBT.isAcquring\n')
            end
            acquiring = ~strcmp(obj.hC.acqState,'idle');
            obj.isScannerAcquiring=acquiring;
        end %isAcquiring

    end %Close of main methods block



    %---------------------------------------------------------------
    methods % This methods block contains additional methods unique to SIBT
        % Perhaps some of the following should be part of scanner, we need to decide
        % Larger methods are in their own files and declared after this block

        function resetTrippedPMTs(obj,resetAll)
            % function resetTrippedPMTs(resetAll)
            %
            % Purpose
            % Resets the trip state on P2100 series.
            % If resetAll is false (which it is by default) we only
            % poll the PMTs corresponding to channels currently being saved.
            % We skip the rest. 

            if nargin<2
                resetAll=false;
            end

            if resetAll==true
                doReset = ones(1,length(obj.hC.hPmts.tripped));
            else
                doReset = zeros(1,length(obj.hC.hPmts.tripped));
                doReset(obj.channelsToAcquire) = 1;
            end
            
            for ii=1:length(obj.hC.hPmts.tripped)
                if doReset(ii) && obj.hC.hPmts.tripped(ii)
                    msg = sprintf('Reset tripped PMT #%d', ii);
                    obj.logMessage(inputname(1) ,dbstack,2, msg)
                    hSI.hC.hPmts.resetTripStatus(ii);
                    hSI.hC.hPmts.setPmtPower(ii,1);
                end
            end
        end %close resetTrippedPMTs

        function framePeriod = getFramePeriod(obj) %TODO: this isn't in the abstract class.
            %return the frame period (how long it takes to acquire a frame) in seconds
            framePeriod = obj.hC.hRoiManager.scanFramePeriod;
        end %getFramePeriod


        function setUpTileSaving(obj)
            if isempty(obj.parent)
                fprintf('SIBT is not attached to BakingTray. Skipping tile saving setup\n')
                return
            end

            obj.hC.hScan2D.logFilePath = obj.parent.currentTileSavePath;
            % TODO: oddly, the file counter automatically adjusts so as not to over-write existing data but 
            % I can't see where it does this in my code and ScanImage doesn't do this if I use it interactively.
            obj.hC.hScan2D.logFileCounter = 1; % Start each section with the index at 1. 


            switch obj.parent.recipe.mosaic.scanmode
            case 'tile'
                obj.hC.hScan2D.logFileStem = sprintf('%s-%04d', ...
                    obj.parent.recipe.sample.ID,obj.parent.currentSectionNumber);
            case 'ribbon'
                obj.hC.hScan2D.logFileStem = sprintf('%s-%04d-%02d', ...
                    obj.parent.recipe.sample.ID, obj.parent.currentSectionNumber, obj.parent.currentOpticalSectionNumber);
            end

            obj.hC.hChannels.loggingEnable = true;
        end %setUpTileSaving


        function disableTileSaving(obj)
            obj.hC.hChannels.loggingEnable=false;
        end


        function initiateTileScan(obj)
            % If tile-scanning, we initiate the next tile simply by issuing a software trigger.
            % If ribbon-scanning, it is triggered from the stage itself when it starts move
            % and so comes in through the PFI line defined in ScanImage, thus initiateTileScan
            % must start a stage motion rather than send a trigger

            if isempty(obj.parent)
                fprintf('SIBT is not attached to BakingTray. Just sending software trigger\n')
                obj.hC.hScan2D.trigIssueSoftwareAcq;
                return
            end

            switch obj.parent.recipe.mosaic.scanmode
            case 'tile'
                obj.hC.hScan2D.trigIssueSoftwareAcq;
            case 'ribbon'
                % Issue a non-blocking Y motion

                %obj.parent.yAxis.resumeInMotionTrigger(1,2)
                yA = obj.parent.currentTilePattern(1,2);
                yB = obj.parent.currentTilePattern(2,2);
                delta = 0.5; %Inter pulse trigger interval from stage in mm
                % fprintf('Producing triggers between %0.2f and %0.2f mm\n', yA-delta, yB+delta)
                if mod(obj.parent.currentTilePosition,2) %If it's odd
                    obj.parent.yAxis.motionTrigMin(2,yB+delta)
                    obj.parent.yAxis.motionTrigMax(2, yA-0)

                    fprintf('Initiating a motion to %0.1f\n', obj.parent.currentTilePattern(2,2) )
                    obj.parent.moveYto(obj.parent.currentTilePattern(2,2), true); 
                else
                    obj.parent.yAxis.motionTrigMin(2,yA-delta)
                    obj.parent.yAxis.motionTrigMax(2,yB+0)

                    fprintf('Initiating a motion to %0.1f\n', obj.parent.currentTilePattern(1,2) )
                    obj.parent.moveYto(obj.parent.currentTilePattern(1,2), true);
                end
                %obj.parent.yAxis.pauseInMotionTrigger(1,2)
            otherwise
                % This will never happen
            end
        end


        function pauseAcquisition(obj)
            obj.acquisitionPaused=true;
        end %pauseAcquisition


        function resumeAcquisition(obj)
            obj.acquisitionPaused=false;
        end %resumeAcquisition


        function maxChans=maxChannelsAvailable(obj)
            maxChans=obj.hC.hChannels.channelsAvailable;
        end %maxChannelsAvailable


        function theseChans = channelsToAcquire(obj,~,~)
            % This is also a listener callback function
            if obj.verbose
                fprintf('Hit SIBT.channelsToAcquire\n')
            end
            theseChans = obj.hC.hChannels.channelSave;

            if ~isequal(obj.channelsToSave,theseChans)
                if obj.verbose
                    fprintf(' channelsToAcquire has changed\n')
                end
                %Then something has changed
                obj.flipScanSettingsChanged
                obj.channelsToSave = theseChans; %store the currently selected channels to save
            end

        end %channelsToAcquire


        function theseChans = channelsToDisplay(obj)
            theseChans = obj.hC.hChannels.channelDisplay;
        end %channelsToDisplay


        function scannerType = scannerType(obj)
            scannerType = lower(obj.hC.hScan2D.scannerType);
        end %scannerType


        function pix=getPixelsPerLine(obj)
            pix =  obj.hC.hRoiManager.pixelsPerLine;
        end % getPixelsPerLine


        function LUT=getChannelLUT(obj,chanToReturn)
            LUT = obj.hC.hChannels.channelLUT{chanToReturn};
        end %getChannelLUT


        function tearDown(obj)
            % Ensure resonant scanner is off
            if strcmpi(obj.scannerType, 'resonant')
                obj.hC.hScan2D.keepResonantScannerOn=false;
            end

            % Turn off PMTs
            obj.hC.hPmts.powersOn(:) = 0;

            % Reset averging to 1 at the end of acquision
            obj.hC.hDisplay.displayRollingAverageFactor=1;
        end


        function verStr = getVersion(obj)
            verStr=sprintf('ScanImage v%s.%s', obj.hC.VERSION_MAJOR, obj.hC.VERSION_MINOR);
        end % getVersion


        function sr = generateSettingsReport(obj)

            % Bidirectional scanning
            n=1;
            st(n).friendlyName = 'Bidirectional scanning';
            st(n).currentValue = obj.hC.hScan2D.bidirectional;
            st(n).suggestedVal = true;


            % Ramping power with Z
            n=n+1;
            st(n).friendlyName = 'Power Z adjust';
            st(n).currentValue = obj.hC.hBeams.pzAdjust;
            if hC.hStackManager.numSlices>1
                suggested = true;
            elseif hC.hStackManager.numSlices==1 
                % Because then it doesn't matter what this is set to and we don't want to 
                % distract the user with stuff that doesn't matter;
                suggested = obj.hC.hBeams.pzAdjust;
            end
            st(n).suggestedVal = suggested

        end % generateSettingsReport

        function showFastZCalib(obj)
            %Conduct fast-z calibration and plot results
            %This will simply run through the Z selected depths 
            [t,expected,~,~,measured] = obj.hC.hFastZ.testActuator;
            f=findobj('name','fastZCalib');
            if isempty(f)
                f=figure;
                f.Name='fastZCalib';
            end
            thisAxis = gca(f);
            p=plot(t,expected,t,measured,'parent',thisAxis);
            p(1).Color=[1,0.25,0.25];
            p(2).Color=[0.25,0.25,1];
            set(p,'LineWidth',2)

            thisAxis.Color=[1,1,1]*0.5;
            thisAxis.XLabel.String = 'Time [s]';
            thisAxis.YLabel.String = 'Distance [\mum]';
            grid(thisAxis,'on')

        end

         function readFrameSizeSettings(obj)
            frameSizeFname=fullfile(BakingTray.settings.settingsLocation,'frameSizes.yml');
            if exist(frameSizeFname, 'file')
                tYML=BakingTray.yaml.ReadYaml(frameSizeFname);
                tFields = fields(tYML);
                popUpText={};
                for ii=1:length(tFields)
                    tSet = tYML.(tFields{ii});

                    % The following is hard-coded in order to make it more likely an error will be
                    % generated here rather than down the line
                    obj.frameSizeSettings(ii).objective = tSet.objective;
                    obj.frameSizeSettings(ii).pixelsPerLine = tSet.pixelsPerLine;
                    obj.frameSizeSettings(ii).linesPerFrame = tSet.linesPerFrame;
                    obj.frameSizeSettings(ii).zoomFactor = tSet.zoomFactor;
                    obj.frameSizeSettings(ii).nominalMicronsPerPixel = tSet.nominalMicronsPerPixel;
                    obj.frameSizeSettings(ii).fastMult = tSet.fastMult;
                    obj.frameSizeSettings(ii).slowMult = tSet.slowMult;
                    obj.frameSizeSettings(ii).objRes = tSet.objRes;

                    %This is used by StitchIt to correct barrel or pincushion distortion
                    if isfield(tSet,'lensDistort')
                        obj.frameSizeSettings(ii).lensDistort = tSet.lensDistort;
                    else
                        obj.frameSizeSettings(ii).lensDistort = [];
                    end
                    %This is used by StitchIt to affine transform the images to correct things like shear and rotation
                    if isfield(tSet,'affineMat')
                        obj.frameSizeSettings(ii).affineMat = tSet.affineMat;
                    else
                        obj.frameSizeSettings(ii).affineMat = [];
                    end
                    %This is used by StitchIt to tweaak the nomincal stitching mics per pixel
                    if isfield(tSet,'stitchingVoxelSize')
                        obj.frameSizeSettings(ii).stitchingVoxelSize = tSet.stitchingVoxelSize;
                    else
                        thisStruct(ii).stitchingVoxelSize = [];
                    end
                end

            else % Report no frameSize file found
                fprintf('\n\n SIBT finds no frame size file found at %s\n\n', frameSizeFname)
                obj.frameSizeSettings=struct;
            end
        end % readFrameSizeSettings


        function nFrames = getNumAverageFrames(obj);
            nFrames=obj.hC.hDisplay.displayRollingAverageFactor;
        end % getNumAverageFrames


        function setNumAverageFrames(obj,nFrames)
            if ~isscalar(nFrames)
                return
            end
            if nFrames<1
                return
            end
            obj.hC.hDisplay.displayRollingAverageFactor=nFrames;
        end % setNumAverageFrames


    end %Close SIBT methods

    methods % SIBT methods in external files
        applyScanSettings(obj,scanSettings)
        scanSettings=returnScanSettings(obj)
        setImageSize(obj,pixelsPerLine,evnt)
        moveFastZTo(obj,targetPositionInMicrons)
    end %Close SIBT methods in external files


    methods (Hidden) %The following are hidden methods specific to SIBT
        function lastFrameNumber = getLastFrameNumber(obj)
            % Returns the number of frames acquired by the scanner.
            % In this case it returns the value of "Acqs Done" from the ScanImage main window GUI. 
            lastFrameNumber = obj.hC.hDisplay.lastFrameNumber;
            %TODO: does it return zero if there are no data yet?
            %TODO: turn into a listener that watches lastFrameNumber
        end


        function enableArmedListeners(obj)
            % Loop through all armedListeners and enable each
            for ii=1:length(obj.armedListeners)
                obj.armedListeners{ii}.Enabled=true;
            end
        end % enableArmedListeners


        function disableArmedListeners(obj)
            % Loop through all armedListeners and disable each
            for ii=1:length(obj.armedListeners)
                obj.armedListeners{ii}.Enabled=false;
            end
        end % disableArmedListeners


        %Listener callback methods
        function enforceSquarePixels(obj,~,~)
            %Ensure that a few key settings are maintained at the correct values
            if obj.allowNonSquarePixels %TODO: this is a bit shit. Should disable the listener. 
                return
            end
            if obj.verbose
                fprintf('Hit SIBT.enforceSquarePixels\n')
            end
            if obj.hC.hRoiManager.forceSquarePixels==false
                obj.hC.hRoiManager.forceSquarePixels=true;
            end
        end %enforceSquarePixels


        function LUTchanged(obj,~,~)
            %Flips the bit if any one of the channel look-up tables has changed
            if obj.verbose
                fprintf('Hit SIBT.LUTchanged\n')
            end

            if isempty(obj.cachedChanLUT)
                for ii=1:length(obj.hC.hChannels.channelSubtractOffset)
                    obj.cachedChanLUT{ii} = obj.getChannelLUT(ii);
                end
                % Flip bit so listeners on other classes notice the change
                obj.channelLookUpTablesChanged=obj.channelLookUpTablesChanged*-1; 
            else
                for ii=1:length(obj.cachedChanLUT)
                    if ~isequal(obj.cachedChanLUT{ii},obj.getChannelLUT(ii))
                        obj.channelLookUpTablesChanged=obj.channelLookUpTablesChanged*-1;
                        if obj.verbose
                            fprintf(' SIBT LUT %d changed\n',ii)
                        end
                        return
                    end
                end
            end %  ifisempty

        end %LUTchanged


        function tileAcqDone_minimal(obj,~,~)
            % Minimal acq done for testing and de-bugging
            obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;
            obj.hC.hScan2D.trigIssueSoftwareAcq;
        end % tileAcqDone_minimal(obj,~,~)


        function tileScanAbortedInScanImage(obj,~,~)
            % This is similar to what happens in the acquisition_view GUI in the "stop_callback"
            if obj.verbose
                fprintf('Hit obj.tileScanAbortedInScanImage\n')
            end
            % Wait for scanner to stop being in acquisition mode
            obj.disableArmedListeners
            obj.abortScanning
            fprintf('Waiting to disarm scanner.')
            for ii=1:20
                if ~obj.isAcquiring
                    obj.disarmScanner;
                    return
                end
                fprintf('.')
                pause(0.25)
            end

            %If we get here we failed to disarm
            fprintf('WARNING: failed to disarm scanner.\nYou should try: >> hBT.scanner.disarmScanner\n')
        end %tileScanAbortedInScanImage

        function changeChecker(obj,s,e)

            variableName = s.Name;  % The name of the variable that might have changed
            variableValue = e.AffectedObject.(variableName); % The current value of the variable

            % If the variable isn't in the buffer, we add it and trigger the change flag.
            if ~isfield(obj.lastSeenScanSettings,variableName)
                obj.lastSeenScanSettings.(variableName) = variableValue;
                obj.flipScanSettingsChanged;
                if obj.verbose
                    fprintf('Added variable %s to SIBT settings cache and assumed it changed\n', variableName)
                end
                return
            end

            %If the current value doesn't equal the previous value, update the previous value and 
            %trigger the change flag
            if ~isequal(obj.lastSeenScanSettings.(variableName), variableValue)
                obj.lastSeenScanSettings.(variableName) = variableValue;
                obj.flipScanSettingsChanged;
                if obj.verbose
                    fprintf('Variable %s appears to have changed in ScanImage\n', variableName)
                end
            end
        end %changeChecker

    end % Closed hidden SIBT methods


    methods (Hidden) %External hidden SIBT-specific methods
        tileAcqDone(obj,~,~) % VERY IMPORTANT - this is the callback that runs the implicit loop
    end  %Close external hidden SIBT-specific methods

end %close classdef
