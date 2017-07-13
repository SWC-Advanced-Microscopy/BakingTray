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
% This version of the class is written against ScanImage 5.2 (2016)
%
% TODO: what does  hSI.hScan2D.scannerToRefTransform do?

    properties
        % If true you get debug messages printed during scanning and when listener callbacks are hit
        verbose=true;
    end

    properties(Hidden,SetObservable)
        %NOTE: this is SIBT-specific right now (17/04/2017)
        channelLookUpTablesChanged=1 %Flips between 1 and -1 if any channel lookup table has changed
    end

    properties (Hidden)
        defaultShutterIDs %The default shutter IDs used by the scanner
        maxStripe=1; %Number of channel window updates per second
        listeners={}
        armedListeners={} %These listeners are enabled only when the scanner is "armed" for acquisition
    end


    methods

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
            %Log default state of settings so we return to these when disarming
            obj.defaultShutterIDs = obj.hC.hScan2D.mdfData.shutterIDs;


            % Add ScanImage-specific listeners

            obj.channelsToAcquire; %Stores the currently selected channels to save in an observable property
            % Update channels to save property whenever the user makes changes in scanImage
%TODO WE COMMENT OUT UNTIL WE SEE WHAT'S SPAMMING THIS  %obj.listeners{end+1}=addlistener(obj.hC.hChannels,'channelSave', 'PostSet', @obj.channelsToAcquire); %TODO: move into SIBT

            obj.listeners{end+1} = addlistener(obj.hC, 'active', 'PostSet', @obj.isAcquiring);

           % obj.enforceImportantSettings
            %Set listeners on properties we don't want the user to change. Hitting any of these
            %will call a single method that resets all of the properties to the values we desire. 
            obj.listeners{end+1} = addlistener(obj.hC.hRoiManager, 'forceSquarePixels', 'PostSet', @obj.enforceImportantSettings);

            obj.LUTchanged
            %obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan1LUT', 'PostSet', @obj.LUTchanged);
            %obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan2LUT', 'PostSet', @obj.LUTchanged);
            %obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan3LUT', 'PostSet', @obj.LUTchanged);
            %obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan4LUT', 'PostSet', @obj.LUTchanged);


            % Add "armedListeners" that are used during tiled acquisition only.
            obj.armedListeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqDone', @obj.tileAcqDone_minimal);
            obj.armedListeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqAbort', @obj.tileScanAbortedInScanImage);
            obj.disableArmedListeners % Because we only want them active when we start tile scanning


            %We now set some values to optimal settings for proceeding, but these are not critical.
            fprintf(' - Setting fast z waveform type to "step"\n')
            obj.hC.hFastZ.waveformType='step'; %Enforced anyway when arming the scanner

            %Supply a reasonable default for the illumination with depth adjustment and report to the command line 
            Lz=180;
            fprintf(' - Setting up power/depth correction using Lz=%d.\n   You may change this value in "POWER CONTROLS". (Smaller numbers will increase the power more with depth.)\n',Lz)
            obj.hC.hBeams.pzAdjust=true;
            obj.hC.hBeams.lengthConstants=Lz;



            success=true;
        end %connect


        function ready = isReady(obj)
            if isempty(obj.hC)
                ready=false;
                return
            end
            ready=strcmpi(obj.hC.acqState,'idle');
        end %isReady


        function success = armScanner(obj)
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
                    obj.hC.hScan2D.trigAcqInTerm='PFI1';
                case 'linear'
                    obj.hC.hScan2D.trigAcqInTerm='PFI0';
            end


            obj.enableArmedListeners

            if obj.hC.hDisplay.displayRollingAverageFactor>1
                fprintf('Setting display rolling average to 1\n')
                obj.hC.hDisplay.displayRollingAverageFactor=1;
            end

            %Set up for Z-stacks if we'll be doing those
            thisRecipe = obj.parent.recipe;
            if thisRecipe.mosaic.numOpticalPlanes>1
                fprintf('Setting up z-scanning with "step" waveform\n')
                obj.hC.hFastZ.waveformType = 'step'; %Always
                obj.hC.hFastZ.numVolumes=1; %Always
                obj.hC.hFastZ.enable=1;

                obj.hC.hStackManager.framesPerSlice = 1; %Always (number of frames per grab per layer)
                obj.hC.hStackManager.numSlices = thisRecipe.mosaic.numOpticalPlanes;
                sliceThicknessInUM = thisRecipe.mosaic.sliceThickness*1E3;
                obj.hC.hStackManager.stackZStepSize = sliceThicknessInUM/obj.hC.hStackManager.numSlices; %Will be uniformly spaced always!
                obj.hC.hStackManager.stackReturnHome = 1;


                fprintf('Setting PIFOC settling time to %0.3f ms\n',...
                    obj.parent.recipe.SYSTEM.objectiveZSettlingDelay);
                obj.hC.hFastZ.flybackTime = obj.parent.recipe.SYSTEM.objectiveZSettlingDelay;

                if obj.parent.recipe.SYSTEM.enableFlyBackBlanking==false
                    fprintf('Switching off beam fly-back blanking. This reduces amplifier ringing artifacts\n')
                    obj.hC.hBeams.flybackBlanking=false;
                end

                if isfield(obj.hC.hScan2D.mdfData,'stripingMaxRate') &&  obj.hC.hScan2D.mdfData.stripingMaxRate>obj.maxStripe
                    %The number of channel window updates per second
                    fprintf('Restricting display stripe rate to %d Hz. This can speed up acquisition.\n',obj.maxStripe)
                    obj.hC.hScan2D.mdfData.stripingMaxRate=obj.maxStripe;
                end

                if strcmp(obj.hC.hDisplay.volumeDisplayStyle,'3D')
                    fprintf('Setting volume display style from 3D to Tiled\n')
                    obj.hC.hDisplay.volumeDisplayStyle='Tiled';
                end

            else
                %Ensure we disable z-scanning
                obj.hC.hStackManager.numSlices = 1;
                obj.hC.hStackManager.stackZStepSize = 0;
            end

            %If any of these fail, we leave the function gracefully
            try
                obj.hC.acqsPerLoop=thisRecipe.numTilesInOpticalSection;% This is the number of x/y positions that need to be visited
                obj.hC.extTrigEnable=1;
                %Put it into acquisition mode but it won't proceed because it's waiting for a trigger
                obj.hC.startLoop;
            catch ME1
                rethrow(ME1)
                return
            end

            success=true;

            obj.hC.hScan2D.mdfData.shutterIDs=[]; %Disable shutters

        end %armScanner


        function success = disarmScanner(obj)
            if obj.hC.active
                obj.logMessage(inputname(1),dbstack,7,'Scanner still in acquisition mode. Can not disarm.')
                success=false;
                return
            end

            %Disable z sectioning
            obj.hC.hFastZ.enable=0;
            hSI.hStackManager.numSlices = 1;

            obj.hC.extTrigEnable=0;  
            obj.hC.hScan2D.mdfData.shutterIDs=obj.defaultShutterIDs; %re-enable shutters
            obj.disableArmedListeners;
            obj.hC.hChannels.loggingEnable=false;

            fprintf('Turning on fly-back blanking\n')
            obj.hC.hBeams.flybackBlanking=true;
            success=true;
        end %disarmScanner


        function abortScanning(obj)
            obj.hC.hCycleManager.abort;
        end


        function acquiring = isAcquiring(obj,~,~)
            %Returns true if a focus, loop, or grab is in progress even if the system is not
            %currently acquiring a frame
            if obj.verbose
                fprintf('Hit SIBT.isAcquiring\n')
            end
            acquiring = ~strcmp(obj.hC.acqState,'idle');
            obj.isScannerAcquiring=acquiring;
        end %isAcquiring


        %---------------------------------------------------------------
        % The following methods are not part of scanner. Maybe they should be, we need to decide
        function framePeriod = getFramePeriod(obj) %TODO: this isn't in the abstract class.
            %return the frame period (how long it takes to acquire a frame) in seconds
            framePeriod = obj.hC.hRoiManager.scanFramePeriod;
        end %getFramePeriod


        function scanSettings = returnScanSettings(obj)
            scanSettings.pixelsPerLine = obj.hC.hRoiManager.pixelsPerLine;
            scanSettings.linesPerFrame = obj.hC.hRoiManager.linesPerFrame;
            scanSettings.micronsBetweenOpticalPlanes = obj.hC.hStackManager.stackZStepSize;
            scanSettings.numOpticalSlices = obj.hC.hStackManager.numSlices;
            scanSettings.zoomFactor = obj.hC.hRoiManager.scanZoomFactor;

            scanSettings.scannerMechanicalAnglePP_fast_axis = round(range(obj.hC.hRoiManager.imagingFovDeg(:,1)),3);
            scanSettings.scannerMechanicalAnglePP_slowAxis =  round(range(obj.hC.hRoiManager.imagingFovDeg(:,2)),3);

            scanSettings.FOV_alongColsinMicrons = round(range(obj.hC.hRoiManager.imagingFovUm(:,1)),3);
            scanSettings.FOV_alongRowsinMicrons = round(range(obj.hC.hRoiManager.imagingFovUm(:,2)),3);

            scanSettings.micronsPerPixel_cols = round(scanSettings.FOV_alongColsinMicrons/scanSettings.pixelsPerLine,3);
            scanSettings.micronsPerPixel_rows = round(scanSettings.FOV_alongRowsinMicrons/scanSettings.linesPerFrame,3);

            scanSettings.framePeriodInSeconds = round(1/obj.hC.hRoiManager.scanFrameRate,3);
            scanSettings.pixelTimeInMicroSeconds = round(obj.hC.hScan2D.scanPixelTimeMean * 1E6,4);
            scanSettings.linePeriodInMicroseconds = round(obj.hC.hRoiManager.linePeriod * 1E6,4);
            scanSettings.bidirectionalScan = obj.hC.hScan2D.bidirectional;
            scanSettings.activeChannels = obj.hC.hChannels.channelSave;

            % Beam power
            scanSettings.beamPower= obj.hC.hBeams.powers;
            scanSettings.beamPowerLengthConstant = obj.hC.hBeams.lengthConstants;
            scanSettings.scanMode= obj.scannerType;
            scanSettings.scannerID=obj.scannerID;

            %Record the detailed image settings to allow for things like acquisition resumption
            scanSettings.pixEqLinCheckBox = obj.hC.hRoiManager.forceSquarePixelation;
            scanSettings.slowMult = obj.hC.hRoiManager.scanAngleMultiplierSlow;
            scanSettings.fastMult = obj.hC.hRoiManager.scanAngleMultiplierFast;
        end %returnScanSettings


        function setUpTileSaving(obj)
            obj.hC.hScan2D.logFilePath = obj.parent.currentTileSavePath;
            % TODO: oddly, the file counter automatically adjusts so as not to over-write existing data but 
            % I can't see where it does this in my code and ScanImage doesn't do this if I use it interactively.
            obj.hC.hScan2D.logFileCounter = 1; % Start each section with the index at 1. 
            obj.hC.hScan2D.logFileStem = sprintf('%s-%04d',obj.parent.recipe.sample.ID,obj.parent.currentSectionNumber); %TODO: replace with something better
            obj.hC.hChannels.loggingEnable = true;
        end %setUpTileSaving


        function initiateTileScan(obj)
            obj.hC.hScan2D.trigIssueSoftwareAcq;
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
            obj.channelsToSave = theseChans; %store the currently selected channels to save
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


        function setImageSize(obj,pixelsPerLine)
            % Change the per pixels line and ensure that the number of lines per frame changes 
            % accordingly to maintain the FOV and ensure pixels are square. This is a bit
            % harder than it needs to be because we allow for non-square images and the way
            % ScanImage deals with this is clunky. 

            %Let's record the image size
            orig = obj.returnScanSettings;

            % Do we have square images?
            pixEqLinCheckBox = obj.hC.hRoiManager.forceSquarePixelation;
            pixEqLin = obj.hC.hRoiManager.pixelsPerLine == obj.hC.hRoiManager.linesPerFrame;

            if pixEqLin
                % It's pretty easy to change the image size if we have square images. 
                if ~pixEqLinCheckBox
                    fprintf('Setting Pix=Lin check box in ScanImage CONFIGURATION window to true\n')
                    obj.hC.hRoiManager.forceSquarePixelation=true;
                end
                obj.hC.hRoiManager.pixelsPerLine=pixelsPerLine;

                else
                    % Handle changes in image size if we have rectangular images
                    slowMult = obj.hC.hRoiManager.scanAngleMultiplierSlow;
                    fastMult = obj.hC.hRoiManager.scanAngleMultiplierFast;

                    obj.hC.hRoiManager.pixelsPerLine=pixelsPerLine;

                    obj.hC.hRoiManager.scanAngleMultiplierFast=fastMult;
                    obj.hC.hRoiManager.scanAngleMultiplierSlow=slowMult;

            end

            % Issue a warning if the FOV of the image has changed after changing the number of pixels. 
            after = obj.returnScanSettings;

            if after.FOV_alongRowsinMicrons ~= orig.FOV_alongRowsinMicrons
                fprintf('WARNING: FOV along rows changed from %d microns to %d microns\n',...
                    orig.FOV_alongRowsinMicrons, after.FOV_alongRowsinMicrons)
            end

            if after.FOV_alongColsinMicrons ~= orig.FOV_alongColsinMicrons
                fprintf('WARNING: FOV along cols changed from %d microns to %d microns\n',...
                    orig.FOV_alongColsinMicrons, after.FOV_alongColsinMicrons)
            end
        end %setImageSize

        function applyScanSettings(obj,scanSettings)
            % Applies a saved set of scanSettings in order to return ScanImage to a 
            % a previous state. e.g. used to resume an acquisition following a crash.
            if ~isstruct(scanSettings)
                return
            end

            % The following z-stack-related settings don't strictly need to be set, 
            % since they are applied when the scanner is armed.
            obj.hC.hStackManager.stackZStepSize = scanSettings.micronsBetweenOpticalPlanes;
            obj.hC.hStackManager.numSlices = scanSettings.numOpticalSlices;

            % Set the laser power and changing power with depth
            obj.hC.hBeams.powers = scanSettings.beamPower;            
            obj.hC.hBeams.lengthConstants = scanSettings.beamPowerLengthConstant;
            % TODO : add the drop-down 

            % Which channels to acquire
            if iscell(scanSettings.activeChannels)
                scanSettings.activeChannels = cell2mat(scanSettings.activeChannels);
            end
            obj.hC.hChannels.channelSave = scanSettings.activeChannels;


            % We set the scan parameters. The order in which these are set matters            
            obj.hC.hRoiManager.scanZoomFactor = scanSettings.zoomFactor;
            obj.hC.hScan2D.bidirectional = scanSettings.bidirectionalScan;
            obj.hC.hRoiManager.forceSquarePixelation = scanSettings.pixEqLinCheckBox;

            obj.hC.hRoiManager.pixelsPerLine = scanSettings.pixelsPerLine;
            if ~scanSettings.pixEqLinCheckBox
                obj.hC.hRoiManager.linesPerFrame = scanSettings.linesPerFrame;
            end

            % Set the scan angle multipliers. This is likely only critical if 
            % acquiring rectangular scans.
            obj.hC.hRoiManager.scanAngleMultiplierSlow = scanSettings.slowMult;
            obj.hC.hRoiManager.scanAngleMultiplierFast = scanSettings.fastMult;
        end %applyScanSettings

    end %close methods


    methods (Hidden)
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
        function enforceImportantSettings(obj,~,~)
            %Ensure that a few key settings are maintained at the correct values
            if obj.verbose
                fprintf('Hit SIBT.enforceImportantSettings\n')
            end
            if obj.hC.hRoiManager.forceSquarePixels==false
                obj.hC.hRoiManager.forceSquarePixels=true;
            end
        end %enforceImportantSettings


        function LUTchanged(obj,~,~)
            if obj.verbose
                fprintf('Hit SIBT.LUTchanged\n')
            end
            obj.channelLookUpTablesChanged=obj.channelLookUpTablesChanged*-1; %Just flip it so listeners on other classes notice the change
        end %LUTchanged


        function tileAcqDone(obj,~,~)
            % This callback function is VERY IMPORTANT it constitutes part of the implicit loop
            % that performs the tile scanning. It is an "implicit" loop, since it is called 
            % repeatedly until all tiles have been acquired.

            %Log theX and Y positions in the grid associated with these tile data
            obj.parent.lastTilePos.X = obj.parent.positionArray(obj.parent.currentTilePosition,1);
            obj.parent.lastTilePos.Y = obj.parent.positionArray(obj.parent.currentTilePosition,2);
            obj.parent.lastTileIndex = obj.parent.currentTilePosition;


            if obj.parent.importLastFrames
                msg='';
                for z=1:length(obj.hC.hDisplay.stripeDataBuffer) %Loop through depths
                    % scanimage stores image data in a data structure called 'stripeData'
                    %ptr=obj.hC.hDisplay.stripeDataBufferPointer; % get the pointer to the last acquired stripeData (ptr=1 for z-depth 1, ptr=5 for z-depth, etc)
                    lastStripe = obj.hC.hDisplay.stripeDataBuffer{z};
                    if isempty(lastStripe)
                        msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} is empty. ',z);
                    elseif ~isprop(lastStripe,'roiData')
                        msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} has no field "roiData"',z);
                    elseif ~iscell(lastStripe.roiData)
                        msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell. It is a %s.',z, class(lastStripe.roiData));
                    elseif length(lastStripe.roiData)<1
                        msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell with length >1',z);
                    end

                    if ~isempty(msg)
                        msg = [msg, 'NOT EXTRACTING TILE DATA IN SIBT.tileAcqDone'];
                        obj.logMessage('acqDone',dbstack,6,msg);
                        break
                    end

                    for ii = 1:length(lastStripe.roiData{1}.channels) % Loop through channels
                        obj.parent.downSampledTileBuffer(:, :, lastStripe.frameNumberAcq, lastStripe.roiData{1}.channels(ii)) = ...
                             int16(imresize(rot90(lastStripe.roiData{1}.imageData{ii}{1},-1),...
                                [size(obj.parent.downSampledTileBuffer,1),size(obj.parent.downSampledTileBuffer,2)],'bicubic'));
                    end

                    if obj.verbose
                        fprintf('%d - Placed data from frameNumberAcq=%d (%d) ; frameTimeStamp=%0.4f\n', ...
                            obj.parent.currentTilePosition, ...
                            lastStripe.frameNumberAcq, ...
                            lastStripe.frameNumberAcqMode, ...
                            lastStripe.frameTimestamp)
                    end
                end % z=1:length...
            end % if obj.parent.importLastFrames


            %Increement the counter and make the new position the current one
            obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;
            pos=obj.parent.recipe.tilePattern;

            if obj.parent.currentTilePosition>size(pos,1)
                fprintf('hBT.currentTilePosition > number of positions. Breaking in SIBT.tileAcqDone\n')
                return
            end

            % Blocking motion
            blocking=true;
            obj.parent.moveXYto(pos(obj.parent.currentTilePosition,1), pos(obj.parent.currentTilePosition,2), blocking); 

            %store stage positions. this is done after all tiles in the z-stack have been acquired
            obj.parent.logPositionToPositionArray
            positionArray=obj.parent.positionArray;

            if obj.hC.hChannels.loggingEnable==true
                save(fullfile(obj.parent.currentTileSavePath,'tilePositions.mat'),'positionArray')
            end

            if obj.hC.active % Could have a smarter check here. e.g. stop only when all volumes 
                              % are in so we generate an error if there's a failure

                while obj.acquisitionPaused
                    pause(0.5)
                end
                obj.hC.hScan2D.trigIssueSoftwareAcq; %Acquire all depths and channeLs at this X/Y position
            end
            obj.logMessage('acqDone',dbstack,2,'->Completed acqDone<-');
        end %tileAcqDone


        function tileAcqDone_minimal(obj,~,~)
            % Minimal acq done for testing and de-bugging
            obj.parent.currentTilePosition = obj.parent.currentTilePosition+1;
            pause(0.5)
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
            fprintf('Waiting to disarm')
            for ii=1:20
                if ~obj.isAcquiring
                    obj.disarmScanner;
                    obj.parent.detachLogObject;
                    return
                end
                fprintf('.')
                pause(0.25)
            end

            %If we get here we failed to disarm
            fprintf('WARNING: failed to disarm scanner.\nYou should try: >> hBT.scanner.disarmScanner\n')

        end %tileScanAbortedInScanImage

    end %hidden methods
end %close classdef
