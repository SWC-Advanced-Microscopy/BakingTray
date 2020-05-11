classdef dummyScanner < scanner
%%
% dummyScanner
%
% The dummy scanner class. 
% Optional loading of data from disk to simulate acquisition 

    properties
        logFilePath
        logFileStem
        logFileCounter
        inAcquiringMode=false;

        % The following properties are highly specific to dummy_scanner
        writeData=false % Only writes data to disk if this is true. 
        existingDataDir %D irectory containing existing data set that we will use 
        metaData % meta data of already existin dataset

        displayAcquiredImages=true
        lastAcquiredTile

        hCurrentImFig  % Handle to the figure window

        %The following properties are highly specific to dummy_scanner
        imageStackData %Downsampled image stack that we "image"
        imageStackVoxelSizeXY %voxel size of loaded stack in x/y
        imageStackVoxelSizeZ %voxel size of loaded stack in z
        maxChans=4; %Arbitrarily, the dummy scanner can handle up to 4 chans. 

        currentOpticalPlane=1

        skipSaving=false %If true we do not write image data but do everything else
    end

    properties (SetObservable)
        stack_clim = [0,100] % Reasonable values for the axis range
    end

    properties (Hidden)
        placeInDownSampledTileBuffer=false; %Changed by arm/disarm scanner

        %NOTE: dummyScanner is only tested with the following three 
        %      properties set to 1.
        numOpticalPlanes=1
        numChannels=1;
        averageEveryNframes=1;

        % Handles to menu items that perform basic actions
        scannerMenu
        acquireTileMenu
        focusStartStopMenu

        hWholeSectionAx
        hWholeSectionPlt
        hCurrentFrameAx
        hCurrentFramePlt

        % These values are calculated by attachPreviewStack so that we don't see the padded 
        % regions when displaying the section image. 
        sectionImage_ylim
        sectionImage_xlim

        hTileLocationBox % Box laid over the section image so we can see where we are

        focusTimer % Used to handle ScanImage "focus-like" streaming to an image window

        settings % to mirror those in SIBT, just in case this is helpful

        scannerSettings % This structure will hold settings that other classes need to acccess
        listeners = {}

        % The following are obtained once each time the scanner is armed at the start of a section
        xStepInMicrons
        yStepInMicrons
        xStepInPixels
        yStepInPixels
    end

    methods

        %constructor
        function obj=dummyScanner(imageSource)
            obj.channelsToSave=1;
            obj.scannerID='dummyScanner';

            obj.focusTimer = timer;
            obj.focusTimer.Name = 'focus image updater';
            obj.focusTimer.Period = 0.25;
            obj.focusTimer.TimerFcn = @(~,~) obj.updateFocusWindow;
            obj.focusTimer.ExecutionMode = 'fixedDelay';

            % Set a listener to flip the channelLookUpTablesChanged flag
            % whenever stack_clim is changed
            obj.listeners{1}=addlistener(obj, 'stack_clim', 'PostSet', @obj.flipClimFlag);

            % Hard-code settings for acquisition behavior
            obj.settings.tileAcq.tileFlipUD=false; % see initiateTileScan
            obj.settings.tileAcq.tileFlipLR=false; % see initiateTileScan
            obj.settings.tileAcq.tileRotate=0;     % see initiateTileScan

            obj.readFrameSizeSettings; % Populate the frame setings 
            obj.scannerSettings = obj.returnDefaultScanSettings;
        end %constructor


        %destructor
        function delete(obj)
            delete(obj.hCurrentImFig)
            obj.hC=[];

            if isa(obj.focusTimer,'timer')
                stop(obj.focusTimer)
                delete(obj.focusTimer)
            end
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        function success = connect(obj,API)
            success=true;
        end %connect


        function ready = isReady(~)
           ready=true;
        end %isReady


        function success = armScanner(obj,~)
            obj.inAcquiringMode=true;
            obj.placeInDownSampledTileBuffer=true;
            % Ensure we run as fast as possible 
            if isa(obj.parent.xAxis,'dummy_linearcontroller')
                obj.parent.xAxis.instantMotions=true;
            end

            if isa(obj.parent.yAxis,'dummy_linearcontroller')
                obj.parent.yAxis.instantMotions=true;
            end

            %tile step size
            obj.xStepInMicrons = obj.parent.recipe.TileStepSize.X*1E3;
            obj.yStepInMicrons = obj.parent.recipe.TileStepSize.Y*1E3;

            obj.xStepInPixels = round(obj.xStepInMicrons / obj.imageStackVoxelSizeXY);
            obj.yStepInPixels = round(obj.yStepInMicrons / obj.imageStackVoxelSizeXY);

            success=true;
        end %armScanner


        function success = disarmScanner(obj,~)
            obj.inAcquiringMode=false;
            obj.placeInDownSampledTileBuffer=false;
            if isa(obj.parent.xAxis,'dummy_linearcontroller')
                obj.parent.xAxis.instantMotions=false;
            end
            if isa(obj.parent.yAxis,'dummy_linearcontroller')
                obj.parent.yAxis.instantMotions=false;
            end
            obj.disableTileSaving;
            success=true;
        end %armScanner


        function abortScanning(obj)
        end


        function showFastZCalib(~,~,~)
            % SIBT does this and so we also do here
        end


        function setUpTileSaving(obj)
            obj.logFilePath = obj.parent.currentTileSavePath;
            obj.logFileCounter = 1; % Start each section with the index at 1. 
            obj.logFileStem = obj.returnTileFname;
            obj.writeData = true;
        end


        function disableTileSaving(obj)
            obj.writeData=false;
        end


        function OUT = returnScanSettings(obj)
            OUT = obj.scannerSettings;
        end


        function acquiring = isAcquiring(obj)
            acquiring=obj.inAcquiringMode;
            obj.isScannerAcquiring=acquiring;
        end %isAcquiring


        function pauseAcquisition(obj)
            obj.acquisitionPaused=true;
        end


        function resumeAcquisition(obj)
            obj.acquisitionPaused=false;
        end


        function maxChans = maxChannelsAvailable(obj)
            maxChans=obj.maxChans;
        end


        function chans = channelsToAcquire(obj)
            chans=1:obj.maxChans;
        end


        function chans = channelsToDisplay(obj)
            chans=obj.channelsToAcquire;
            chans=chans(1);
        end


        function scannerType = scannerType(obj)
            scannerType = 'linear';
        end %scannerType


        function setImageSize(obj,~,~)
        end


        function pixelsPerLine = getPixelsPerLine(obj)
            S=obj.returnScanSettings;
            pixelsPerLine=S.pixelsPerLine;
        end


        function LUT = getChannelLUT(obj,~,~)
            LUT=obj.stack_clim;
        end


        function tearDown(~)
        end


        function verStr=getVersion(~)
            verStr='dummy scanner';
        end


        function sr = generateSettingsReport(~)
            sr=[];
        end


        function applyZstackSettingsFromRecipe(obj,~,~)
            obj.numOpticalPlanes=obj.parent.recipe.mosaic.numOpticalPlanes;
        end


        function applyScanSettings(~,~)
        end


        function nFrames = getNumAverageFrames(obj);
            nFrames=obj.averageEveryNframes;
        end


        function setNumAverageFrames(~,~)
        end



        %---------------------------------------------------------------
        % The following methods are specific to the dummy_scanner class. They allow the scanner
        % to load images from an existing image stack using StitchIt, in order to simulate data acquisition. 
        function getClim(obj)
            % Uses the loaded image stack to get a reasonable range for the look-up table
            tmp = single(obj.imageStackData(1:10:end));
            [n,x] = hist(tmp,500);
            cc = cumsum(n)/sum(n);
            f=find(cc>0.9); % to get 90th percentile
            obj.stack_clim = [0,x(f(1))]; % This is observable and triggers obj.flipClimFlag
        end

        function flipClimFlag(obj,~,~)
            % Toggle this observable variable to allow other classes to update lookup tables
            obj.channelLookUpTablesChanged = obj.channelLookUpTablesChanged*-1;
        end


        function startFocus(obj,~,~)
            % Runs the acquire tile method continuously with a timer
            obj.displayAcquiredImages=true;
            obj.acquireTile % Ensure window is present
            start(obj.focusTimer)

            % Update the focus menu
            obj.focusStartStopMenu.Text='Stop Focus';
            obj.focusStartStopMenu.Callback=@obj.stopFocus;
        end % start focus

        function stopFocus(obj,~,~)
            % Stops simulated focus acquisition
            stop(obj.focusTimer)
            obj.displayAcquiredImages=true;

            % Update the focus menu
            obj.focusStartStopMenu.Text='Start Focus';
            obj.focusStartStopMenu.Callback=@obj.startFocus;
        end % stop focus

    end %close methods

    methods (Hidden=true)
        function figCloseFcn(obj,~,~)
            if strcmp(obj.focusTimer.Running,'on')
                fprintf('Stopping focus\n')
                obj.stopFocus
            end
            delete(obj.hCurrentImFig)
        end

        function updateFocusWindow(obj,~,~)
            f=findobj('Tag','CurrentDummyImFig');
            if isempty(f)
                return
            end

            try
                obj.acquireTile;
            catch ME 
                disp(ME.message)
                obj.stopFocus
            end
        end % updateFocusWindow

    end % Hidden methods

end %close classdef 