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
% NOTE ON TRIGGERS:
% NI linear scanners tigger on PFI0, reso NI on PFI1, and vDAQ on D0.0
% Therefore do not use those ports for other stuff.
%
% TODO: what does  hSI.hScan2D.scannerToRefTransform do?

    properties
        % If true you get debug messages printed during scanning and when listener callbacks are hit
        verbose=false
        settings
        leaveResonantScannerOnWhenArmed = true
    end

    properties (Hidden)
        maxStripe=1; %Number of channel window updates per second
        listeners={}
        armedListeners={} %These listeners are enabled only when the scanner is "armed" for acquisition
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
            obj.settings = readSIBTsettings;
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
            success=false;

            if nargin<2 || isempty(API)
               API = SIBT.get_hSI_from_base;
            end

            if isempty(API)
                return
            end

            obj.hC=API;

            fprintf('\n\nStarting SIBT interface for ScanImage\n')


            % Add ScanImage-specific listeners

            obj.getChannelsToAcquire; %Stores the currently selected channels to save in an observable property
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

            % Watch the pixel bin factor and sample rate if we have linear scanners
            if strcmp('linear',obj.scannerType)
                obj.listeners{end+1}=addlistener(obj.hC.hScan2D, 'pixelBinFactor', 'PostSet', @(src,evt) obj.changeChecker(src,evt));
                obj.listeners{end+1}=addlistener(obj.hC.hScan2D, 'sampleRate', 'PostSet', @(src,evt) obj.changeChecker(src,evt));
            end

            % Add "armedListeners" that are used during tiled acquisition only.
            obj.armedListeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqDone', @obj.tileAcqDone);
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


        function success = disarmScanner(obj)
            if obj.hC.active
                obj.logMessage(inputname(1),dbstack,7,'Scanner still in acquisition mode. Can not disarm.')
                success=false;
                return
            end

            obj.hC.extTrigEnable=0;
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


        function leaveResonantScannerOn(obj)
            % If this is a resonant system, turn on the scanner for the rest of the acqiosotion.
            % This method is called by armScanner and possibly outside of the SIBT class also
            if strcmpi(obj.scannerType, 'resonant')
                % This will only be turned off again when the teardown method is run
                obj.hC.hScan2D.keepResonantScannerOn=obj.leaveResonantScannerOnWhenArmed;
            end
        end %leaveResonantScannerOn


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
                doReset(obj.getChannelsToAcquire) = 1;
            end

            for ii=1:length(obj.hC.hPmts.tripped)
                if doReset(ii) && obj.hC.hPmts.tripped(ii)
                    msg = sprintf('Reset tripped PMT #%d', ii);
                    obj.logMessage(inputname(1) ,dbstack,2, msg)
                    if obj.versionGreaterThan('2020')
                        % For sure 2020 onwards does this but I don't know exactly when the
                        % change happened.
                        obj.hC.hPmts.hPMTs{ii}.resetTrip;
                        obj.hC.hPmts.hPMTs{ii}.setPower(1);
                    else
                        % Older versions of ScanImage use this system.
                        hSI.hC.hPmts.resetTripStatus(ii);
                        hSI.hC.hPmts.setPmtPower(ii,1);
                    end
                end
            end
        end %close resetTrippedPMTs

        function enabledPMTs=getEnabledPMTs(obj)
            % function enabledPMTs=getEnabledPMTs(obj)
            %
            % Purpose
            % Return a vector indicating which PMTs are currently enabled
            enabledPMTs = find(obj.hC.hPmts.powersOn);
            enabledPMTs = enabledPMTs(:);
        end

        function success = disablePMTautoPower(obj)
            % function success = disablePMTautoPower(obj)
            %
            % Purpose
            % Disable PMT auto power and return true if it
            % succeeded. False if it failed
            %
            % Note: in SI BASIC 2021 this seems not to change the setting
            obj.hC.hPmts.autoPower(:)=0;
            if any(obj.hC.hPmts.autoPower)
                success = false;
            else
                success = true;
            end
        end % disablePMTautoPower

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

            obj.hC.hScan2D.logFileStem = obj.returnTileFname;

            obj.hC.hChannels.loggingEnable = true;

            % Close all histogram windows in case this slows down acquisition
            SIBT.closeAllHistogramWindows
        end %setUpTileSaving


        function disableTileSaving(obj)
            obj.hC.hChannels.loggingEnable=false;
        end


        function initiateTileScan(obj)
            % We are tile-scanning so can initiate the next tile simply by issuing a software trigger.
            obj.hC.hScan2D.trigIssueSoftwareAcq;
        end


        function pauseAcquisition(obj)
            % see SIBT.tileAcqDone to understand how this works
            obj.acquisitionPaused=true;
        end %pauseAcquisition


        function resumeAcquisition(obj)
            % see SIBT.tileAcqDone to understand how this works
            obj.acquisitionPaused=false;
        end %resumeAcquisition


        function maxChans=maxChannelsAvailable(obj)
            maxChans=obj.hC.hChannels.channelsAvailable;
        end %maxChannelsAvailable


        function chanNames = getChannelNames(obj,~,~)
            chanNames = obj.hC.hPmts.names;
        end % getChannelNames


        function theseChans = getChannelsToAcquire(obj,~,~)
            % This is also a listener callback function
            if obj.verbose
                fprintf('Hit SIBT.getChannelsToAcquire\n')
            end
            theseChans = obj.hC.hChannels.channelSave(:);

            if ~isequal(obj.channelsToSave,theseChans)
                if obj.verbose
                    fprintf(' channelsToAcquire has changed\n')
                end
                %Then something has changed
                obj.flipScanSettingsChanged
                obj.channelsToSave = theseChans; %store the currently selected channels to save
            end

        end %getChannelsToAcquire


        function theseChans = getChannelsToDisplay(obj)
            theseChans = obj.hC.hChannels.channelDisplay(:);
        end %getChannelsToDisplay


        function setChannelsToAcquire(obj,chans)
            % Ensure chans is valid
            chans = unique(chans);
            chans(chans<1)=[];
            chans(chans>obj.maxChannelsAvailable)=[];

            if ~isequal(obj.channelsToSave,chans)
                if obj.verbose
                    fprintf(' channelsToAcquire has changed\n')
                end
                %Then something has changed
                obj.flipScanSettingsChanged
                obj.channelsToSave = theseChans; %store the currently selected channels to save
            end

            obj.hC.hChannels.channelSave = chans;
        end % setChannelsToAcquire


        function setChannelsToDisplay(obj,chans)
            % Ensure chans is valid
            chans = unique(chans);
            chans(chans<1)=[];
            chans(chans>obj.maxChannelsAvailable)=[];

            obj.hC.hChannels.channelDisplay = chans(:)'; %must be a row vector or SI not happy
        end % setChannelsToDisplay


        function scannerType = scannerType(obj)
            % Since SI 5.6, scanner type "resonant" is returned as "rg"
            % This method returns either "resonant" or "linear"
            scannerType = lower(obj.hC.hScan2D.scannerType);
            if strcmpi('RG',scannerType) || strcmpi('resonant',scannerType)
                scannerType = 'resonant';
            elseif strcmpi('GG',scannerType)
                scannerType='linear';
            end
        end % scannerType


        function pix=getPixelsPerLine(obj)
            pix =  obj.hC.hRoiManager.pixelsPerLine;
        end % getPixelsPerLine


        function LUT=getChannelLUT(obj,chanToReturn)
            LUT = obj.hC.hChannels.channelLUT{chanToReturn};
        end % getChannelLUT


        function SR=getSampleRate(obj)
            SR=obj.hC.hScan2D.sampleRate;
        end % getSampleRate


        function pixBin=getPixelBinFactor(obj)
            pixBin=obj.hC.hScan2D.pixelBinFactor;
        end % getPixelBinFactor


        % Some settings have moved between ScanImage versions. These methods
        % help use to take this into account
        function setLoc = fastZsettingLocation(obj)
            % String defining where the fast z settings live in the API
            % Used like this: obj.hC.(obj.fastZsettingLocation)
            %
            % See also: obj.getFastZWaveformtype and obj.applyZstackSettingsFromRecipe
            if obj.versionGreaterThan('5.6.1')
                setLoc = 'hStackManager';
            else
                setLoc = 'hFastZ';
            end
        end % fastZsettingLocation


        function setLoc = fastZwaveformLocation(obj)
            % String defining where the fast z waveform lives in the API
            % Used like this: obj.hC.(obj.fastZsettingLocation).(obj.fastZwaveformLocation)
            %
            % See also: obj.getFastZWaveformtype and obj.applyZstackSettingsFromRecipe
            if obj.versionGreaterThan('5.6.1')
                setLoc = 'stackFastWaveformType';
            else
                setLoc = 'waveformType';
            end
        end % fastZwaveformLocation


        function waveformType = getFastZWaveformType(obj)
            waveformType = obj.hC.(obj.fastZsettingLocation).(obj.fastZwaveformLocation);
        end % getFastZWaveformType


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
            % Return a string listing the current version of ScanImage and current version of MATLAB
            verStr=sprintf('%s on MATLAB %s', obj.hC.version, version);
        end % getVersion


        function isGreater = versionGreaterThan(obj,verToTest)
            % Return true if the current ScanImage version is newer than that defined by string verToTest
            %
            % SIBT.versionGreaterThan(obj,verToTest)
            %
            % Inputs
            % verToTest - should be in the format '5.6' or '5.6.1' or
            % '2020.0'
            %
            % Note: this method does not know what to do with the update
            % mumber from SI Basic. So 2020.1 is OK but 2020.1.4 won't
            % produce correct results

            isGreater = nan;
            if ~ischar(verToTest)
                return
            end

            % Add '.0' if needed
            if length(strfind(verToTest,'.'))==0
                verToTest = [verToTest,'.0'];
            end

            % Turn string into a number
            verToTestAsNum = str2num(strrep(verToTest,'.',''));

            % Current version
            curVersion = [obj.hC.VERSION_MAJOR,obj.hC.VERSION_MINOR];
            if ischar(curVersion(1))
                % Likely this a free release
                curVersionAsNum = str2num(strrep(curVersion,'.',''));
            else
                % Likely this is Basic or Premium
                curVersionAsNum = curVersion(1)*10 + curVersion(2);
            end

            isGreater = curVersionAsNum>verToTestAsNum;
        end % versionGreaterThan


        function st = generateSettingsReport(obj)
            % TODO -- this method is not used by anything and seems
            % unfinished. Delete?
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
            st(n).suggestedVal = suggested;

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
                    obj.frameSizeSettings(ii).sampRate = [];
                    obj.frameSizeSettings(ii).pixBin = [];

                    if isfield(tSet,'shiftSlow')
                        obj.frameSizeSettings(ii).shiftSlow = tSet.shiftSlow;
                    else
                        obj.frameSizeSettings(ii).shiftSlow = [];
                    end

                    if isfield(tSet,'shiftFast')
                        obj.frameSizeSettings(ii).shiftFast = tSet.shiftFast;
                    else
                        obj.frameSizeSettings(ii).shiftFast = [];
                    end

                    if isfield(tSet,'spatialFillFrac')
                        obj.frameSizeSettings(ii).spatialFillFrac = tSet.spatialFillFrac;
                    else
                        obj.frameSizeSettings(ii).spatialFillFrac = [];
                    end

                    if isfield(tSet,'sampRate')
                        obj.frameSizeSettings(ii).sampRate = tSet.sampRate;
                    end
                    if isfield(tSet,'pixBin')
                        obj.frameSizeSettings(ii).pixBin = tSet.pixBin;
                    end

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
                docURL = 'https://bakingtray.mouse.vision/getting-started/installation/calibration/calibrating-the-number-of-microns-per-pixel-with-scanimage';
                fprintf('\n\n SIBT finds no frame size file found at %s\n\nPlease see:\n%s\n', ...
                    frameSizeFname, docURL)

                obj.frameSizeSettings=[];
            end
        end % readFrameSizeSettings

        function laserPower = returnLaserPowerInmW(obj)
            if obj.versionGreaterThan('2021')
                currentPower = obj.hC.hBeams.powers;
                laserPower = obj.hC.hBeams.hBeams{1}.convertPowerFraction2PowerWatt(currentPower/100)*1000;
            else
                laserPower = nan;
            end
            laserPower = round(laserPower);
        end % returnLaserPowerInmW

        function nFrames = getNumAverageFrames(obj)
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


        function out = is_vDAQ(obj)
            % Retrun tru if this is a vDAQ
            out = isa(obj.hC.hScan2D,'scanimage.components.scan2d.RggScan');
        end %is_vDAQ


    end %Close SIBT methods

    methods % SIBT methods in external files
        applyScanSettings(obj,scanSettings)
        scanSettings=returnScanSettings(obj)
        setImageSize(obj,pixelsPerLine,evnt)
        moveFastZTo(obj,targetPositionInMicrons)
        applyZstackSettingsFromRecipe(obj)
        [success,msg] = doScanSettingsMatchRecipe(obj,tRecipe)
        applyLaserCalibration(obj,laserPower)
    end %Close SIBT methods in external files


    methods (Hidden) %The following are hidden methods specific to SIBT

        function lastFrameNumber = getLastFrameNumber(obj)
            % Returns the number of frames acquired by the scanner.
            % In this case it returns the value of "Acqs Done" from the ScanImage main window GUI.
            lastFrameNumber = obj.hC.hDisplay.lastFrameNumber;
            %TODO: does it return zero if there are no data yet?
            %TODO: turn into a listener that watches lastFrameNumber
        end %getLastFrameNumber


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
