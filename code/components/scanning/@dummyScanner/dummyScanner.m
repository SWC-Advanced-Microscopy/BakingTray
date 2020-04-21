classdef dummyScanner < scanner
%%
% dummyScanner
%
% The dummy scanner class. 
% Optional loading of data from disk to simulate acquisition 

    properties
        TStream %A cell array of tiffstreams objects that hold the image data
                %one per channel. Hold data for the current section only.
        logFilePath
        logFileStem
        logFileCounter
        inAcquiringMode=false;

        %The following properties are highly specific to dummy_scanner
        writeData=false %Only writes data to disk if this is true. 
        existingDataDir %Directory containing existing data set that we will use 
        metaData %meta data of already existin dataset

        simulateAcquisition = false %if true, we attempt to load an existing dataset to simulate acquisition
        displayAcquiredImages=true
        lastAcquiredTile
    end

    properties (Hidden)
        %The following properties are highly specific to dummy_scanner
        imageStackData %Downsampled image stack that we "image"
        imageStackVoxelSizeXY %voxel size of loaded stack in x/y
        imageStackVoxelSizeZ %voxel size of loaded stack in z
        maxChans=4; %Arbitrarily, the dummy scanner can handle up to 4 chans. 

        currentPhysicalSection=1
        currentOpticalPlane=1

        numOpticalPlanes=1
        averageEveryNframes=1;

        hCurrentImFig

        focusTimer % Used to handle ScanImage "focus-like" streaming to an image window
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
        end %constructor


        %destructor
        function delete(obj)
            obj.hC=[];
            obj.delete(obj.hCurrentImFig)

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
            success=true;
        end %armScanner

        function success = disarmScanner(obj,~)
            obj.inAcquiringMode=false;
            success=true;
        end %armScanner

        function abortScanning(obj)
        end

        function showFastZCalib(~,~,~)
            % SIBT does this and so we also do here
        end

        function setUpTileSaving(~)
        end

        function disableTileSaving(~)
        end

        function initiateTileScan(~)
        end

        function acquiring = isAcquiring(obj)
            acquiring=obj.inAcquiringMode;
            obj.isScannerAcquiring=acquiring;
        end %isAcquiring

        function OUT = returnScanSettings(obj)
            %TODO - these settings can't be changed by interacting the GUI
            OUT.pixelsPerLine=512;
            OUT.linesPerFrame=512;
            OUT.micronsBetweenOpticalPlanes=10;

            OUT.FOV_alongColsinMicrons=775;
            OUT.FOV_alongRowsinMicrons=775;

            OUT.micronsPerPixel_cols=OUT.FOV_alongColsinMicrons/OUT.pixelsPerLine;
            OUT.micronsPerPixel_rows=OUT.FOV_alongRowsinMicrons/OUT.linesPerFrame;

            OUT.framePeriodInSeconds = 0.5;
            OUT.pixelTimeInMicroSeconds = (OUT.framePeriodInSeconds * 1E6) / (OUT.pixelsPerLine * OUT.linesPerFrame);
            OUT.linePeriodInMicroseconds = OUT.pixelTimeInMicroSeconds * OUT.pixelsPerLine;
            OUT.bidirectionalScan = true;
            OUT.activeChannels = 1:4;
            OUT.beamPower= 10; %percent
            OUT.scannerType='simulated';
            OUT.scannerID=obj.scannerID;
            OUT.slowMult = 1;
            OUT.fastMult = 1;
            OUT.zoomFactor =1;
            OUT.numOpticalSlices=obj.numOpticalPlanes;
            OUT.averageEveryNframes=obj.averageEveryNframes;
        end

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

        function pixPerLine = getPixelsPerLine(obj)
            S=obj.returnScanSettings;
            pixelsPerLine=S.pixelsPerLine;
        end

        function LUT = getChannelLUT(~,~)
            LUT=[0,5E3];
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

        function nFrames = getNumAverageFrames(~);
            nFrames=obj.averageEveryNframes;
        end

        function setNumAverageFrames(~,~)
            fprintf('** dummyScanner.setNumAverageFrames does nothing\n')
        end



        %---------------------------------------------------------------
        % The following methods are specific to the dummy_scanner class. They allow the scanner
        % to load images from an existing image stack using StitchIt, in order to simulate data acquisition. 
        function attachPreviewStack(obj,pStack,voxelSize)
            %  function attachPreviewStack(obj,pStack)
            %
            %  e.g.
            %  load some_pStack
            %  hBT.scanner.attachExistingData(pStack)

            % Add data to object
            obj.imageStackData=pStack.imStack;
            obj.imageStackVoxelSizeXY = pStack.voxelSizeInMicrons;
            obj.imageStackVoxelSizeZ = pStack.recipe.mosaic.sliceThickness;

            % Set the number of optical planes to 1, as we won' be doing this here
            obj.numOpticalPlanes=1;
            obj.parent.recipe.mosaic.numOpticalPlanes=obj.numOpticalPlanes;
            obj.currentPhysicalSection=1;
            obj.currentOpticalPlane=1;
        end




        function startFocus(obj)
            % Runs the acquire tile method continuously with a timer
            obj.displayAcquiredImages=true;
            obj.acquireTile % Ensure window is present
            start(obj.focusTimer)
        end % start focus

        function stopFocus(obj)
            % Stops simulated focus acquisition
            stop(obj.focusTimer)
            obj.displayAcquiredImages=true;
        end % stop focus

    end %close methods

    methods (Hidden=true)
        function updateFocusWindow(obj,~,~)
            % Focus timer callback
            obj.displayAcquiredImages=false; % Because this method does it
            f=findobj('Tag','CurrentDummyImFig');
            if isempty(f)
                return
            end
            tObj=findobj('Tag','tileImage');
            obj.acquireTile;
            tObj.CData=obj.lastAcquiredTile;
            drawnow
            obj.displayAcquiredImages=true;
        end % updateFocusWindow
    end % Hidden methods

end %close classdef 