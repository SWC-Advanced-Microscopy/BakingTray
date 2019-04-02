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
    end

    methods

        %constructor
        function obj=dummy_scanner(imageSource)
            obj.channelsToSave=1;
            obj.scannerID='dummyScanner';
        end %constructor


        %destructor
        function delete(obj)
            obj.hC=[];
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

        function success = acquireTile(obj,~)
            % ===========>   TODO: this is currently broken   <==============
            %If image stack data have been added, then we can fake acquisition of an image. Otherwise skip.
            if isempty(obj.imageStackData)
                success=true;
                return
            end

            thisSection = obj.imageStackData(:,:,obj.currentDepth);
            if isempty(thisSection)
                fprintf('No data attached. Skipping image generation\n')
                return
            end
            XYpos=obj.parent.getXYpos;
            xPosInMicrons = abs(XYpos(1))*1E3 ; %ABS HACK TODO
            yPosInMicrons = abs(XYpos(2))*1E3 ; %ABS HACK TODO

            %tile step size
            xStepInMicrons = obj.parent.recipe.TileStepSize.X*1E3;
            yStepInMicrons = obj.parent.recipe.TileStepSize.Y*1E3;


            %position in slice is
            xRange = ceil([xPosInMicrons,xPosInMicrons+xStepInMicrons]/obj.imageStackVoxelSizeXY);
            yRange = ceil([yPosInMicrons,yPosInMicrons+yStepInMicrons]/obj.imageStackVoxelSizeXY);
            if xRange(1)==0
                xRange=xRange+1;
            end
            if yRange(1)==0
                yRange=yRange+1;
            end

            tile = thisSection(xRange(1):xRange(2),yRange(1):yRange(2));
            obj.lastAcquiredTile=tile;
            if obj.displayAcquiredImagesdis
                clf
                imagesc(tile)
                set(gca,'Clim',[0,6.8E3])
                axis equal off
                colormap gray
                set(gcf,'color','k')
                drawnow
                pause(0.1)
            end
            success=true;

            if obj.writeData
                %SAVE
            end
        end % acquireTile


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

        function setImageSize(~,~)
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

        function applyScanSettings(~,~)
        end

        function nFrames = getNumAverageFrames(~);
            nFrames=1;
        end

        function setNumAverageFrames(~,~)
        end
        
        %---------------------------------------------------------------
        % The following methods are specific to the dummy_scanner class. They allow the scanner
        % to load images from an existing image stack using StitchIt, in order to simulate data acquisition. 
        function attachExistingData(obj,imageStack,voxelSize)
            obj.imageStackData=imageStack;
            obj.imageStackVoxelSizeXY = voxelSize(1);
            obj.imageStackVoxelSizeZ = voxelSize(2);

            %set the recipe to match the data
            obj.parent.recipe.mosaic.numOpticalPlanes=1;

        end

        function readFrameSizeSettings
            %TODO: will ultimately cause problems because it does nothing, but it's unlikely this will be an issue in practice
        end

    end %close methods

end %close classdef 