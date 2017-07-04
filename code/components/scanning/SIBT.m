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

    end

    properties(Hidden,SetObservable)
        %NOTE: this is SIBT-specific right now (17/04/2017)
        channelLookUpTablesChanged=1 %Flips between 1 and -1 if any channel lookup table has changed
    end

    properties (Hidden)
        defaultShutterIDs %The default shutter IDs used by the scanner
        maxStripe=1; %Number of channel window updates per second
        listeners={}
        allowedSampleRates=[1.25E6,2.5E6]; %TODO: for now, because the 6124 is not working as it should
    end


    methods

        %constructor
        function obj=SIBT(API)
            if nargin<1
                API=[];
            end
            obj.connect(API);

        end %constructor


        %destructor
        function delete(obj)
            cellfun(@delete,obj.listeners)
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

            %Set up a user frame-acquired callback.
            U(1).EventName='frameAcquired';
            U(1).UserFcnName='BT_SI_userFunction';
            U(1).Arguments={};
            U(1).Enable=0;

            U(2).EventName='acqDone';
            U(2).UserFcnName='BT_SI_userFunction';
            U(2).Arguments={};
            U(2).Enable=0;

            U(3).EventName='acqModeStart';
            U(3).UserFcnName='BT_SI_userFunction';
            U(3).Arguments={};
            U(3).Enable=0;

            U(4).EventName='acqModeDone';
            U(4).UserFcnName='BT_SI_userFunction';
            U(4).Arguments={};
            U(4).Enable=0;

            obj.hC.hUserFunctions.userFunctionsCfg=U; %TODO: BUG!! This will wipe the existing user functions

            switch obj.scannerType
                case 'resonant'
                    %To make it possible to enable the external trigger. PFI0 is reserved for resonant scanning
                    obj.hC.hScan2D.trigAcqInTerm='PFI1';
                case 'linear'
                    obj.hC.hScan2D.trigAcqInTerm='PFI0';
            end


            %Add ScanImage-specific listeners

            obj.channelsToAcquire; %Stores the currently selected channels to save in an observable property
            % Update channels to save property whenever the user makes changes in scanImage
            obj.listeners{end+1}=addlistener(obj.hC.hChannels,'channelSave', 'PostSet', @obj.channelsToAcquire); %TODO: move into SIBT

            %Set up a listener on the sample rate to ensure it's a safe value
            obj.listeners{end+1} = addlistener(obj.hC.hScan2D, 'sampleRate', 'PostSet', @obj.keepSampleRateWithinBounds);
            obj.listeners{end+1} = addlistener(obj.hC, 'active', 'PostSet', @obj.isAcquiring);

            obj.enforceImportantSettings
            %Set listeners on properties we don't want the user to change. Hitting any of these
            %will call a single method that resets all of the properties to the values we desire. 
            obj.listeners{end+1} = addlistener(obj.hC.hRoiManager, 'forceSquarePixels', 'PostSet', @obj.enforceImportantSettings);
            obj.listeners{end+1} = addlistener(obj.hC.hScan2D, 'bidirectional', 'PostSet', @obj.enforceImportantSettings);


            obj.LUTchanged
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan1LUT', 'PostSet', @obj.LUTchanged);
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan2LUT', 'PostSet', @obj.LUTchanged);
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan3LUT', 'PostSet', @obj.LUTchanged);
            obj.listeners{end+1}=addlistener(obj.hC.hDisplay,'chan4LUT', 'PostSet', @obj.LUTchanged);



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

            %TODO: add checks to confirm that all of the following happened
            obj.toggleUserFunction('BT_SI_userFunction',true);

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
            %TODO: how to abort a loop?
            %TODO: use the listeners to run this method if the user presses "Abort"
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
            obj.toggleUserFunction('BT_SI_userFunction',false);
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
            scanSettings.activeChannels = obj.channelsToAcquire;
            scanSettings.beamPower= obj.hC.hBeams.powers;
            scanSettings.scanMode= obj.scannerType;
        end %returnScanSettings


        function setUpTileSaving(obj)
            %TODO: add to abstract class
             obj.hC.hScan2D.logFilePath = obj.parent.currentTileSavePath;
             obj.hC.hScan2D.logFileCounter = 1; %Start each section with the index at 1
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

    end %close methods


    methods (Hidden)
        function lastFrameNumber = getLastFrameNumber(obj)
            % Returns the number of frames acquired by the scanner. 
            % In this case it returns the value of "Acqs Done" from the ScanImage main window GUI. 
            lastFrameNumber = obj.hC.hDisplay.lastFrameNumber;
            %TODO: does it return zero if there are no data yet?
            %TODO: turn into a listener that watches lastFrameNumber

        end

        function success=toggleUserFunction(obj,UserFcnName,toggleStateTo)
            %find userfunction with UserFcnName and tioggle its Enable state to toggleStateTo
            success=false;
            if isempty(obj.hC.hUserFunctions.userFunctionsCfg)
                obj.logMessage(inputname(1),dbstack,7,'ScanImage contains no user functions')
                return
            end

            names={obj.hC.hUserFunctions.userFunctionsCfg.UserFcnName};
            ind=strmatch(UserFcnName,names,'exact');

            if isempty(ind)
                msg=sprintf('Can not find user function names %s',UserFcnName);
                obj.logMessage(inputname(1),dbstack,7,msg)
                return
            end

            if length(ind)>1
                msg=sprintf('Disabling %d user functions with name %s', length(ind),UserFcnName);
                obj.logMessage(inputname(1),dbstack,2,msg)
            end

            for ii=1:length(ind)
                obj.hC.hUserFunctions.userFunctionsCfg(ind(ii)).Enable=toggleStateTo;
            end
            success=true;
        end %toggleUserFunction


        %Listener callback functions
        function keepSampleRateWithinBounds(obj,~,~)
            if ~any(obj.allowedSampleRates == obj.hC.hScan2D.sampleRate)
                obj.hC.hScan2D.sampleRate=obj.allowedSampleRates(1);
                %TODO: SHORT TERM HACK!
                fprintf('Setting sample rate to a safe value. Only some rates work currently with the PXIe-6124\n')
            end

        end %keepSampleRateWithinBounds

        function enforceImportantSettings(obj,~,~)
            %Ensure that a few key settings are maintained at the correct values
            if obj.hC.hRoiManager.forceSquarePixels==false
                obj.hC.hRoiManager.forceSquarePixels=true;
            end
            if obj.hC.hScan2D.bidirectional==false
                obj.hC.hScan2D.bidirectional=true;
            end
        end %enforceImportantSettings

        function LUTchanged(obj,~,~)
            obj.channelLookUpTablesChanged=obj.channelLookUpTablesChanged*-1; %Just flip it so listeners on other classes notice the change
        end %LUTchanged

    end %hidden methods
end %close classdef
