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

        function readFrameSizeSettings(obj)
            % Right now we just copy this from SIBT (31/08/2019 -- Rob Campbella)
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
                fprintf('\n\n dummyScanner finds no frame size file found at %s\n\n', frameSizeFname)
                obj.frameSizeSettings=struct;
            end
        end % function readFrameSizeSettings(obj)


        %---------------------------------------------------------------
        % The following methods are specific to the dummy_scanner class. They allow the scanner
        % to load images from an existing image stack using StitchIt, in order to simulate data acquisition. 
        function attachExistingData(obj,imageStack,voxelSize)
            %  function attachExistingData(obj,imageStack,voxelSize)
            %
            %  e.g.
            %  TT = load3DTiff('someData.tiff');
            %  hBT.scanner.attachExistingData(TT,[7,10])

            obj.imageStackData=imageStack;
            obj.imageStackVoxelSizeXY = voxelSize(1);
            obj.imageStackVoxelSizeZ = voxelSize(2);

            %set the recipe to match the data
            obj.parent.recipe.mosaic.numOpticalPlanes=obj.numOpticalPlanes;
            obj.currentPhysicalSection=1;
            obj.currentOpticalPlane=1;
        end


        function varargout = acquireTile(obj,~)
            %If image stack data have been added, then we can fake acquisition of an image. Otherwise skip.
            if isempty(obj.imageStackData)
                success=false;
                if nargout>0
                    varargout{1}=success;
                end
                return
            end

            tDepth = obj.numOpticalPlanes * (obj.currentPhysicalSection-1) + obj.currentOpticalPlane;
            if size(obj.imageStackData,3)<tDepth
                fprintf('Current desired depth %d is out of bounds. Loaded stack has %d planes.\n',...
                    tDepth, size(obj.imageStackData,3))
                return
            end
            thisSection = obj.imageStackData(:,:,tDepth);

            [X,Y]=obj.parent.getXYpos;
            xPosInMicrons = abs(X)*1E3 ; %ABS HACK TODO
            yPosInMicrons = abs(Y)*1E3 ; %ABS HACK TODO

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
            if obj.displayAcquiredImages
            % Open figure window as needed
                f=findobj('Tag','CurrentDummyImFig');
                if isempty(f)
                    obj.hCurrentImFig = figure;
                    obj.hCurrentImFig.Tag='CurrentDummyImFig';
                else
                    clf(f)
                end

                tileIm=imagesc(tile);
                tileIm.Tag='tileImage';
                %set(gca,'Clim',[min(thisSection(:)), max(thisSection(:))])
                axis equal off
                colormap gray
                set(gcf,'color',[1,0.9,0.9]*0.1)
                drawnow
            end

            success=true;

            if nargout>0
                varargout{1}=success;
            end

            if obj.writeData
                %SAVE
            end
        end % acquireTile

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