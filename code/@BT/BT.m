classdef BT < loghandler
% BT - This is the master BakingTray class for control of automated serial-section 2p tomography
%
% Purpose
% BT is the master microscope control class. This is where most of the awesome stuff
% happens. BT inherits loghandler. Unlike the component classes, BT does not inherit
% an abstract class.
%
% Also see the bootstrap function "BakingTray.m", which starts an instance of BakingTray 
% in a user-friendly manner.
%
% Examples
% e.g.
%  B=buildDummyControllers;
%  hBT=BT(B);
%  hBT.attachRecipe('recipe_example.yml');


    properties (Transient)
        scanner % The object that handles the scanning (e.g. SIBT, our scanImage wrapper)
        cutter  % The vibrotome motor 
        laser   % An object providing control of the laser goes here. If present, BakingTray can
                % can turn off the laser at the end of the experiment and stop acquisition if the
                % laser fails. If it's missing, these features just aren't available.
        recipe  % The details for the experiment go here

        % These properties control the three axis sample stage.
        xAxis
        yAxis
        zAxis
        buildFailed=true  % True if BT failed to build all components at startup
        disabledAxisReadyCheckDuringAcq=true % If true, we don't check whether stages are ready to 
                                             % move before each motion when we are in an acquisition
        previewTilePositions % Pixel locations defining where tiles will be placed in the lastPreviewImageStack.
                             % We take into account the overlap between tiles: BT.initialisemodel)
        autoROI = [] % All info related to the autoROI goes here.
    end %close properties


    properties (Hidden)
        saveToDisk = 1 %By default we save to disk when running
        % By default a "FINISHED" is written to the acquisition directory when the sample completes.
        % The user may wish to skip this if they stop the acquisition early for some reason (e.g. to 
        % change a cutting parameter then re-start)
        completeAcquisitionOnBakeLoopExit = true

        logPreviewImageDataToDir = '' %If a valid path, any preview image in view_acquire is saved here during cutting

        % Cached/stored settings
        % Log front/left position when the preview stack (BT.lastPreviewImageStack) is taken. 
        % We need to do this because BT.convertImageCoordsToStagePosition calculates stage position 
        % based on this value. We can't use the recipe front/left position because then the stage coords
        % derived from the image would be wrong until the user re-acquires a preview stack.
        frontLeftWhenPreviewWasTaken = struct('X',[],'Y',[]);

        % Log files stored here. This is a new property (Dec 2021) so it will take a while to migrate
        % everything as downstream processing will be affected by this change. 
        logFilePath = 'logfiles'

        % Directory to keep old, backup, log files generated during things like acquisition resumes
        backupDir = 'bak'
    end


    properties (SetObservable)
        lastPreviewImageStack = [] % The last preview image stack. It is a 4D matrix: [pixel rows, pixel columns, z depth, channel]
    end


    properties (SetAccess=immutable,Hidden)
        componentSettings
        rawDataSubDirName='rawData' % Section directories will be placed in this sub-directory.
        autoROIstats_fname='auto_ROI_stats.mat' % The statistics associated with auto-ROI acquisitions will be saved to this file name in rawDataSubDirName
    end


    % Short flags or variables used during acquisition
    properties (SetObservable,AbortSet,Transient)
        sampleSavePath=''       % The absolute path in which all data related to the current sample will be saved.
        leaveLaserOn=false      % If true, the laser is not switched off when acquisition finishes.
        sliceLastSection=false  % If true, the last section is sliced. If false it's left on the face of the block
        importLastFrames=true   % If true, we keep a copy of the frames acquired at the last X/Y position in BT.downSampledTileBuffer
        processLastFrames=true; % If true we downsample, these frames, rotate, calculate averages, or similar TODO: define this
    end


    % Message structure. Messages to be displayed to the command line are written to these properies
    % The BT.displayMessage method prints them to screen. The reason for this is that the view classes
    % for the GUI also monitor this same structure and display a dialog box if appropriate. Furthermore,
    % we can set up particular sorts of messages to be formatted differently depending on messageID.
    %
    % The messageString property contains the text to be displayed. 
    % The mesageID property is for internal use only and could contain flags so that messages are, say,
    % skipped by the GUI. 
    % IMPORTANT: functions wishing to write a message MUST write to messageID first then messageString. 
    % This is because BT.displayMessage listens to messageString and will read what is in messageID
    % immediately after the messageString is changed.
    % NOTE: only write messages to messageString that you would like to be displayed in the GUI too.
    properties (SetObservable,Transient)
        messageID = ''
        messageString = ''
    end


    %The following are counters and temporary variables used during acquistion
    properties (Hidden,SetObservable,AbortSet,Transient)
        currentTileSavePath=''  % The path to which data for the currently acquired section are being saved (see BT.defineSavePath)
        currentSectionNumber=1  % The current section
        currentTilePosition=1   % The current index in the X/Y grid. This is used by the scanimage user function to know where in the grid we are
        positionArray           % Array of stage positions that we save to disk
        sectionCompletionTimes  % A vector containing the number of seconds it took to acquire the data for each section (including cutting)
        currentTilePattern      % The cached currently used tilePattern. Saves having to regenerate each time from the recipe
        keepAllDownSampledTiles = false; % If true, all downsampled tiles for one section are stored in the property allDownsampledTilesOneSection
                                         % This is used only for debugging so keepAllDownSampledTiles should generally be false.

        % The last acquired tiles go here. With ScanImage, all tiles from the last x/y position will be stored in
        % scanner.tileBuffer should be 
        downSampledTileBuffer = [] % A 4D array: [imageRows,imageCols,zDepths,channels]; 
        % The following parameter defines the number of microns per pixel of the downsampled image.
        % It is set to 20 microns/pixel by default. ** The autoROI feature is tested only at 20 mics/pix **
        % If you change this value the autoROI might not work as expected. In addition, decreasing this value 
        % will slow down the autoROI slightly. 
        downsampleMicronsPerPixel = 20;
        %i.e. 1,2,3,... not a position in mm)
        lastTilePos =  struct('X',0,'Y',0);  %The X and Y positions in the grid
        lastTileIndex = 0; %This tells us which row in the tile pattern the last tile came from

    end

    properties (Hidden)
        listeners = {};
        allDownsampledTilesOneSection = {}
    end

    properties (Hidden,SetObservable,AbortSet,Transient,Dependent)
        % The following dependent properties make file paths (but don't check if the paths are valid)
        pathToSectionDirs % This will be fullfile(obj.sampleSavePath,obj.rawDataSubDirName)
        thisSectionDir % Path to the current section directory based on the current section number and sample ID in recipe
    end

    % These properties are used by GUIs and general broadcasting
    properties (SetObservable, AbortSet)
        acquisitionState='idle'     % Can be "idle", "bake", or "preview"
        acquisitionInProgress=false % This indicates that an acquisition is under way (distinct from scanner.isScannerAcquiring). 
                                    % The acquisitionInProgress bool goes high when the acquisition begins and only returns low 
                                    % once all sections have been acquired. 
    end

    properties (Hidden, SetObservable, AbortSet)
        isSlicing=false
        abortSlice=false %Used as a flag to tell BT.sliceSection to abort the cutting routine
        abortAcqNow=false  %Used when aborting an acquisition
        abortAfterSectionComplete=false %If true, BT will abort after the current section has finished
    end


    % Declare methods in separate files
    methods
        % startup-related
        varargout=attachCutter(obj,settings)
        success=attachLaser(obj,settings)
        success=attachMotionAxes(obj,settings)
        success=attachRecipe(obj,fname,resume)
        varargout=attachScanner(obj,settings)
        success=checkAttachedStages(obj,ControllerObject,axisName)

        % Key methods that trigger acquisition events
        sectionInd = bake(obj,varargin)
        takeRapidPreview(obj)
        runSuccess = runTileScan(obj,boundingBoxDetails) %is called by bake and takeRapidPreview

        % Acquisition-related helper functions
        success = defineSavePath(obj) 
        [acquisitionPossible,msg] = checkIfAcquisitionIsPossible(obj,isBake)
        [cuttingPossible,msg] = checkIfCuttingIsPossible(obj)
        [cutSeries,msg] = genAutoTrimSequence(obj,lastSliceThickness)
        [success,msg] = resumeAcquisition(obj,recipeFname,varargin)
        abortSlicing(obj)
        finished = sliceSample(obj,sliceThickness,cuttingSpeed)
        [stagePos,mmPerPixelDownSampled] = convertImageCoordsToStagePosition(obj, coords, imageFrontLeft)
        [imageCoords,mmPerPixelDownSampled] = convertStagePositionToImageCoords(obj, coords, imageFrontLeft)
        populateCurrentTilePattern(obj, varargin)
        msg = reportAcquisitionSize(obj)

        % House-keeping
        out = estimateTimeRemaining(obj,scnSet,numTilesPerOpticalSection)
        success=renewLaserConnection(obj)
        success=initialisePreviewImageData(obj,tp, frontLeft)
        preAllocateTileBuffer(obj)
        slack(obj,message)
        n=tilesRemaining(obj)


        % auto-ROI related
        success=getNextROIs(obj)
        getThreshold(obj)
        pStack = returnPreviewStructure(obj)
    end % Declare methods in separate files


    methods (Hidden)
        logPositionToPositionArray(obj,fakeLog)

        % Callbacks
        placeNewTilesInPreviewData(obj,~,~)
        displayMessage(obj,~,~)
    end


    methods
        %Constructor
        function obj=BT(varargin)
            clc
            fprintf('Starting construction of BT object\n')
            % Check if an instance of BT already exists and return *that*.
            % So it is never possible to have more than one instance of BT created. 
            W=evalin('base','whos');
            varClasses = {W.class};
            ind=strmatch('BT',varClasses);

            if ~isempty(ind)
                fprintf('An instance of BT already exists in the base workspace.\n')
                obj=evalin('base',W(ind).name);
                return
            end


            %Parse optional arguments
            params = inputParser;
            params.CaseSensitive = false;
            params.addParameter('componentSettings',[], @(x) isstruct(x) || isempty(x))
            params.parse(varargin{:});

            % Test read of the system settings file. It will be created if not present. 
            % Nothing is done with the system settings at this point. The settings are 
            % are read by the recipe file. 
            BakingTray.settings.readSystemSettings;

            %Read the component settings found by BakingTray.settings.readComponentSettings
            %if none were provided. The most likely reason for providing a different file
            %is to set up dummy components. See optional input arguments of BakingTray.m
            obj.componentSettings=params.Results.componentSettings;

            if isempty(obj.componentSettings)
                fprintf('BT.BT is reading default component settings with BakingTray.settings.readComponentSettings\n')
                obj.componentSettings=BakingTray.settings.readComponentSettings;
            end


            fprintf('\n\n BakingTray starting...\n Connecting to hardware components:\n\n')

            obj.attachScanner(obj.componentSettings.scanner);
            if isempty(obj.scanner)
                fprintf('Failed to connect to scanner.\n')
            end

            try
                success=obj.attachMotionAxes(obj.componentSettings.motionAxis);
            catch ME1
                disp(ME1.message)
                success=false;
            end


            if ~success
                fprintf('BT.attachMotionAxes failed to build one or more axes. Not starting BT.\n')
                delete(obj);
                return
            end

            obj.attachCutter(obj.componentSettings.cutter);
            if isempty(obj.cutter)
                fprintf('Failed to connect to cutter. Not starting BT.\n')
                delete(obj);
                return
            end

            %TODO: for now at least, don't fail if there is no connection to the scanner and laser
            obj.attachLaser(obj.componentSettings.laser);
            if isempty(obj.laser)
                fprintf('Failed to connect to laser.\n')
            end

            %Attach the default recipe
            fprintf('BT.BT is loading default recipe\n')
            obj.attachRecipe;

            % Read the stage positions so they are stored in the stage objects. This ensures that any 
            % methods that might rely on the stage currentPosition properties aren't fed an empty array.
            [x,y]=obj.getXYpos;
            z=obj.getZpos;

            % Ensure that x/y stage speeds are what they should be
            obj.setXYvelocity(obj.recipe.SYSTEM.xySpeed)


            % Add a listener on currentTilePosition, which updates the section preview
            obj.listeners{1}=addlistener(obj, 'currentTilePosition', 'PostSet', @obj.placeNewTilesInPreviewData);
            % Listener to display messages to CLI
            obj.listeners{end+1}=addlistener(obj, 'messageString', 'PostSet', @obj.displayMessage);
            obj.buildFailed=false;

        end %Constructor

        %Destructor
        function obj=delete(obj) 
            disp('Cleaning up BT object')
            if obj.isXaxisConnected
                obj.xAxis.delete
            end
            if obj.isYaxisConnected
                obj.yAxis.delete
            end
            if obj.isZaxisConnected
                obj.zAxis.delete
            end
            if obj.isCutterConnected
                obj.cutter.delete
            end
            if obj.isLaserConnected
                obj.laser.delete
            end
            if obj.isScannerConnected
                obj.scanner.delete
            end

        end  %Destructor


        % ----------------------------------------------------------------------
        % Public methods for moving the X/Y stage an interacting with it
        function getStageStatus(obj)
            %Print to screen status of each axis
            obj.xAxis.printAxisStatus
            obj.yAxis.printAxisStatus
            obj.zAxis.printAxisStatus
        end

        function varargout=moveXYto(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            % Absolute move position defined by xPos and yPos
            %
            % moveXYto(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            %
            % Inputs [required]
            % xPos - x stage target position in mm
            % yPos - y stage target position in mm
            %
            % Inputs [optional]
            % blocking - [false by default] Wait for motion to complete before returning
            % extraSettlingTime is an additional waiting period after the end of a blockin motion.
            %   This extra wait is used when tile scanning to ensure that vibration has ceased. zero by default.
            % timeOut (inf by default) if true, we don't wait longer than
            %  this many seconds for motion to complete
            %

            if nargin<3
                success=false;
                fprintf('moveXYto expects two input arguments: xPos and yPos in mm -- NOT MOVING\n')
                return
            end
            if nargin<4
                blocking=false;
            end
            if nargin<5
                extraSettlingTime=0;
            end
            if nargin<6
                timeOut=inf;
            end

            success=obj.moveXto(xPos) & obj.moveYto(yPos);

            if nargout>0
                varargout{1}=success;
            end

            % This ensures dummy acquisitions run as fast as possible
            if isa(obj.yAxis,'dummy_linearcontroller')
                return
            end

            if blocking && success
                obj.waitXYsettle(extraSettlingTime,timeOut)
            end

        end %moveXYto

        function varargout=moveXYby(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            % Relative move defined by xPos and yPos
            % Wait for motion to complete before returning if blocking is true. 
            % blocking is false by default.
            % extraSettlingTime is an additional waiting period after the end of a blockin motion.
            % This extra wait is used when tile scanning to ensure that vibration has ceased. zero by default.
            % timeOut (inf by default) if true, we don't wait longer than
            % this many seconds for motion to complete
            %
            % varargout=moveXYby(obj,xPos,yPos,blocking,extraSettlingTime,timeOut)
            if nargin<3
                success=false;
                fprintf('moveXYby expects two input arguments: xPos and yPos in mm -- NOT MOVING\n')
                return
            end
            if nargin<4
                blocking=false;
            end
            if nargin<5
                extraSettlingTime=0;
            end
            if nargin<6
                timeOut=inf;
            end

            success = obj.moveXby(xPos) & obj.moveYby(yPos);

            if blocking && success
                obj.waitXYsettle(extraSettlingTime,timeOut)
            end

            if nargout>0
                varargout{1}=success;
            end
        end %moveXYby

        function waitXYsettle(obj,extraSettlingTime,timeOut)
            % Purpose
            % Blocks whilst either of the stages is moving then, optionally,
            % waits extraSettlingTime seconds then returns. There is also 
            % an option to time-out if the motion reports as incomplete.
            %
            % waitXYsettle(obj,extraSettlingTime,timeOut)
            %
            % By default, extraSettlingTime is zero and timeOut is
            % infinite. Currently this is implemented only for relative and
            % absolute X/Y motions. 
            if nargin<2
                extraSettlingTime=0;
            end
            if nargin<3
                timeOut=inf;
            end

            obj.logMessage(inputname(1),dbstack,2,'Waiting for motion to complete')

            tic

            while obj.isXYmoving
                pause(0.01)
                if toc>timeOut
                    obj.logMessage(inputname(1),dbstack,4,'Timed out waiting for motion to complete')
                    break
                end
            end %while
            pause(extraSettlingTime)
        end %waitXYsettle

        function isMoving = isXYmoving(obj)
            %returns true if either the x or y axis is currently moving

            xM=obj.xAxis.isMoving;
            yM=obj.yAxis.isMoving;
            isMoving = yM | xM;
        end

        function success=stopXY(obj)
            % Stop motion of the X and Y stages
            success = obj.xAxis.stopAxis & obj.yAxis.stopAxis;
        end



        % ----------------------------------------------------------------------
        % Public methods for moving the X/Y stage with respect to the sample
        function success = toFrontLeft(obj)
            %Move stage to the front left position (the starting position for a manual-ROI grid tile scan)
            success=false;
            if isempty(obj.recipe)
                return
            end

            FL = obj.recipe.FrontLeft;
            if isempty(FL.X) || isempty(FL.Y)
                fprintf('Front/Left position has not been set.')
                return
            end
            success=obj.moveXYto(FL.X,FL.Y,true); %blocking motion
        end

        function success = toFirstTilePosition(obj)
            %Move stage to the first position in the tile grid. This may differ from the 
            %Front/Left position if we are doing an auto-ROI acquisition
            success=false;
            if isempty(obj.recipe) || isempty(obj.positionArray)
                return
            end
            success=obj.moveXYto(obj.positionArray(1,3),obj.positionArray(1,4),true); %blocking motion
        end % toFirstTilePosition


        % ----------------------------------------------------------------------
        % Public methods for moving the Z stage
        function success =  lowerZstage(obj)
            %Lowers the Z stage to the bottom (zero mm) and performs a homing operation if 
            % necessary. The z-jack lowered position MUST also be the home position.
            % The homing motion is only performed if the recipe SYSTEM.homeZjackOnZeroMove
            % setting is true and we are approaching zero from a position greater than
            % 20 mm away (indicating a sample was likely imaged). Otherwise we simply lower
            % the z-stage as normal to zero, 

            if obj.recipe.SYSTEM.homeZjackOnZeroMove && obj.zAxis.axisPosition>20
                % Approach the home position with a regular non-blocking motion then home.
                fprintf('Moving Z-jack to zero and homing it\n')
                obj.moveZto(1,1); % Go to 1 mm above zero in a blocking motion
                obj.zAxis.referenceStage;
            end

            % Now go to zero (should already be there if we homed)
            obj.moveZto(0,1);
            obj.zAxis.axisPosition; % To update the GUI
            success = true;
        end % lowerZstage

        function success = moveZto(obj,position,blocking)
            % Absolute z-stage motion
            %
            % function success = moveZto(obj,position,blocking)
            %
            % position - value in mm
            % blocking - if true block until motion complete

            if nargin<3, blocking=1; end %blocking by default. Otherwise it homes if it gets a command whilst executing another
            success=obj.zAxis.absoluteMove(position);
            if ~success, return, end

            obj.logMessage(inputname(1),dbstack,2,sprintf('moving Z to %0.3f',position))
            if blocking
                while obj.zAxis.isMoving;
                    pause(0.05)
                end
            end
        end %moveZto

        function moveZby(obj,distanceToMove,blocking)
            % Relative z-stage motion
            %
            % function success = moveZby(obj,position,blocking)
            %
            % position - value in mm
            % blocking - if true block until motion complete

            if nargin<3, blocking=1; end %blocking by default. Otherwise it homes if it gets a command whilst executing another
            success=obj.zAxis.relativeMove(distanceToMove);
            if ~success, return, end

            obj.logMessage(inputname(1),dbstack,2,sprintf('moving Z by %0.3f',distanceToMove))
            if blocking
                while obj.zAxis.isMoving;
                    pause(0.05)
                end
            end
        end %moveZby

        function success=stopZ(obj)
            % stops z motion
            success = obj.zAxis.stopAxis;
        end

        %TODO: all these methods feel like too much duplication. I don't like it. 
        %If the objects are named properly then I feel it should be possible to do away with a lot of this

        % ----------------------------------------------------------------------
        % Convenience methods to query axis position 
        function pos = getXpos(obj)
            % Return the position of the X stage in mm
            pos=obj.xAxis.axisPosition;
        end

        function pos = getYpos(obj)
            % Return the position of the Y stage in mm
            pos=obj.yAxis.axisPosition;
        end

        function pos = getZpos(obj)
            %print to screen if no outputs asked for
            pos=obj.zAxis.axisPosition;
        end

        function varargout = getXYpos(obj)
            %print to screen if no outputs asked for
            X=obj.getXpos;
            Y=obj.getYpos;
            if nargout<1
                fprintf('X=%0.2f, Y=%0.2f\n',X,Y)
                return
            end
            if nargout>0
                varargout{1}=X;
            end
            if nargout>1
                varargout{2}=Y;
            end
        end


        % ----------------------------------------------------------------------
        % Convenience methods to get or set properties of the stage motions:
        % maxSpeed and acceleration
        function vel = getXvelocity(obj)
            % Get the target speed of the X stage in mm/s
            vel=obj.xAxis.getMaxVelocity;
        end
        function vel = getYvelocity(obj)
            % Get the target speed of the Y stage in mm/s
            vel=obj.yAxis.getMaxVelocity;
        end
        function vel = getZvelocity(obj)
            % Get the target speed of the Z stage in mm/s
            vel=obj.zAxis.getMaxVelocity;
        end

        function varargout = setXvelocity(obj,velocity)
            success=obj.xAxis.setMaxVelocity(velocity);
            obj.logMessage(inputname(1),dbstack,2,sprintf('set X velocity to %0.3f',velocity))
            if nargout>0
                varargout{1}=success;
            end
        end
        function varargout = setYvelocity(obj,velocity)
            success=obj.yAxis.setMaxVelocity(velocity);
            obj.logMessage(inputname(1),dbstack,2,sprintf('set Y velocity to %0.3f',velocity))
            if nargout>0
                varargout{1}=success;
            end
        end
        function varargout = setZvelocity(obj,velocity)
            success=obj.zAxis.setMaxVelocity(velocity);
            obj.logMessage(inputname(1),dbstack,2,sprintf('set Z velocity to %0.3f',velocity))
            if nargout>0
                varargout{1}=success;
            end
        end
        function varargout = setXYvelocity(obj,velocity)
            sX=obj.xAxis.setMaxVelocity(velocity);
            sY=obj.yAxis.setMaxVelocity(velocity);
            success = sX & sY;
            obj.logMessage(inputname(1),dbstack,2,sprintf('set X and Y velocity to %0.3f',velocity))
            if nargout>0
                varargout{1}=success;
            end
        end


        % Brief convenience methods
        function [stagesReferenced,stagesToRef] = allStagesReferenced(obj)
            % BT.allStagesReferenced
            %
            % [stagesReferenced,stagesToRef] = allStagesReferenced(obj)\
            %
            % Behavior
            % stagesReferenced is true of all axes are referenced
            % stagesToRef is empty if all stages are referenced. 
            % If stages need referencing, returns a cell array of stage
            % names to reference. e.g. if x and y stages need referencing
            % then it returns {'xAxis','yAxis'}
            
            stagesReferenced = true;
            stagesToRef = {};
            axesToTest = {'xAxis','yAxis','zAxis'};
            for ii=1:length(axesToTest)
                if obj.(axesToTest{ii}).isStageReferenced == false
                    stagesToRef{end+1} = axesToTest{ii};
                    stagesReferenced = false;
                end
            end
        end %allStagesReferenced


        function referenceRequiredAxes(obj,stagesToRef)
            % Reference all unreferenced axes or axes defined in cell array
            % stagesToRef.
            % BT.referenceRequiredAxes(obj,stagesToRef)
            
            if nargin<2
                [~,stagesToRef] = obj.allStagesReferenced;
            end
            
            if isempty(stagesToRef)
                return
            end
            
            for ii=1:length(stagesToRef)
                obj.(stagesToRef{ii}).referenceStage;
            end
            % Now move all referenced axes to their zero position in case
            % this was not the reference location
            for ii=1:length(stagesToRef)
                obj.(stagesToRef{ii}).absoluteMove(0);
                while obj.xAxis.isMoving
                    pause(0.1)
                end
                obj.(stagesToRef{ii}).axisPosition;
            end
        end %referenceRequiredAxes


        function acqLogFname = acquisitionLogFileName(obj)
            %This is the file name of the log file that sits in the sample root directory
            if ~obj.isRecipeConnected
                acqLogFname=[];
            end
            acqLogFname = fullfile(obj.sampleSavePath, ['acqLog_',obj.recipe.sample.ID,'.txt']);
        end %acquisitionLogFileName


        function acqLogWriteLine(obj,msg,fname)
            % Writes text to the acquisition log file that sits in the sample root directory. 
            % Be careful not to overwrite this if it exists, since we may be resuming a 
            % previously aborted acquisition. So we append a line text to the acquisition log file
            if nargin<3
                fname=obj.acquisitionLogFileName;
            end
            if isempty(fname)
                return
            end
            fid = fopen(fname,'a+');
            if fid<1
                fprintf('FAILED to write to acquisition log file at %s\n',fname)
                return
            end
            fprintf(fid,msg);
            fclose(fid);
        end %acqLogWriteLine


        function makeLoggingDir(obj)
            % Make a directory into which logging files can be stored
            if ~exist(obj.sampleSavePath)
                fprintf('Sample dir %s does not exist. Can not make log dir.\n')
                return 
            end

            loggingDir = fullfile(obj.sampleSavePath,obj.logFilePath);
            if ~exist(loggingDir)
                mkdir(loggingDir)
            end
        end % makeLoggingDir


        function makeLoggingBackupDir(obj)
            % Make a directory into which logging files can be stored
            if ~exist(obj.sampleSavePath)
                fprintf('Sample dir %s does not exist. Can not make log dir.\n')
                return 
            end

            obj.makeLoggingDir

            bakDir = fullfile(obj.sampleSavePath,obj.logFilePath,obj.backupDir);
            if ~exist(bakDir)
                mkdir(bakDir)
            end
        end % makeLoggingBackupDir

    end %close methods


    methods (Hidden)
        % ----------------------------------------------------------------------
        % Convenience motion methods
        % The following are convenience methods so we don't have to specify
        % the stage identity each time. This is just the price of having a more
        % flexible system and allowing for the possibility of multiple stages per
        % controller, even though systems we work with don't have this. 

        % - - -  Absolute moves - - - 
        function success = moveXto(obj,position,blocking)
            if nargin<3, blocking=0; end
            success=obj.xAxis.absoluteMove(position);

            if ~success || isa(obj.xAxis,'dummy_linearcontroller')
                return
            end

            obj.logMessage(inputname(1),dbstack,2,sprintf('moving X to %0.3f',position))

            if blocking
                while obj.xAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveXto

        function success = moveYto(obj,position,blocking)
            if nargin<3, blocking=0; end
            success=obj.yAxis.absoluteMove(position);

            if ~success || isa(obj.yAxis,'dummy_linearcontroller')
                return
            end

            obj.logMessage(inputname(1),dbstack,2,sprintf('moving Y to %0.3f',position))


            if blocking
                while obj.yAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveYto

        % - - -  Relative moves - - - 
        function success = moveXby(obj,distanceToMove,blocking)
            if nargin<3, blocking=0; end
            success=obj.xAxis.relativeMove(distanceToMove);
 
            if ~success || isa(obj.xAxis,'dummy_linearcontroller')
                return
            end

            obj.logMessage(inputname(1),dbstack,2,sprintf('moving X by %0.3f',distanceToMove))

            if blocking
                while obj.xAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveXby

        function success = moveYby(obj,distanceToMove,blocking)
            if nargin<3, blocking=0; end
            success=obj.yAxis.relativeMove(distanceToMove);

            if ~success || isa(obj.yAxis,'dummy_linearcontroller')
                return
            end

            obj.logMessage(inputname(1),dbstack,2,sprintf('moving Y by %0.3f',distanceToMove))

            if blocking
                while obj.yAxis.isMoving
                    pause(0.05)
                end
            end
        end %moveYby


        %House-keeping functions
        function msg = checkForPrepareComponentsThatAreNotConnected(obj)
            %Returns empty if everything is connected. Otherwise returns 
            %message string detailing what the problem is. This is used
            %by view classes to display error messages. 
            msg=[];
            if ~obj.isRecipeConnected
                msg =[msg,'No recipe connected\n'];
            end
            if ~obj.isCutterConnected
                msg =[msg,'No cutter connected\n'];
            end
            if ~obj.isXaxisConnected
                msg =[msg,'No X stage connected\n'];
            end
            if ~obj.isYaxisConnected
                msg =[msg,'No Y stage connected\n'];
            end
            if ~obj.isZaxisConnected
                msg =[msg,'No Z stage connected\n'];
            end
        end

        function isConnected=isLaserConnected(obj)
            isConnected=obj.isComponentConnected('laser');
        end %isLaserConnected

        function isConnected=isScannerConnected(obj)
            % TODO: consider whether the hC check needs to be added to isComponentConnected, since all
            % components but the recipe class could potentially benefit from it. 
            isConnected=obj.isComponentConnected('scanner');
            if ~isConnected || isa(obj.scanner,'dummyScanner')
                return
            else
                %Further tests
                isConnected = ~isempty(obj.scanner.hC) && isvalid(obj.scanner.hC);
            end    
        end %isScannerConnected

        function isConnected=isRecipeConnected(obj)
            isConnected=obj.isComponentConnected('recipe');
        end %isRecipeConnected

        function isConnected=isCutterConnected(obj)
            isConnected=obj.isComponentConnected('cutter');
        end %isCutterConnected

        function isConnected=isXaxisConnected(obj)
            isConnected=obj.isComponentConnected('xAxis','linearcontroller');
        end %isXaxisConnected

        function isConnected=isYaxisConnected(obj)
            isConnected=obj.isComponentConnected('yAxis','linearcontroller');
        end %isYaxisConnected

        function isConnected=isZaxisConnected(obj)
            isConnected=obj.isComponentConnected('zAxis','linearcontroller');
        end %isZaxisConnected

        function isConnected=isComponentConnected(obj,componentName,componentClass)
            % Return true if component defined by string "componentName" is connected
            if nargin<3
                componentClass=componentName;
            end
            isConnected=false;
            if ~isempty(obj.(componentName)) && isa(obj.(componentName),componentClass) && isvalid(obj.(componentName))
                isConnected=true;
            else
                isConnected=false;
            end
        end %isComponentConnected

    end % close hidden methods (motion)

    methods
        %These methods are getters and setters
        function out = get.pathToSectionDirs(obj)
            % This is the full path to the sample directory
            out = fullfile(obj.sampleSavePath, obj.rawDataSubDirName);
        end %get.pathToSectionDirs

        function out = get.thisSectionDir(obj)
            % This is the directory into which we will place data for this section
            sectionDir = sprintf('%s-%04d', obj.recipe.sample.ID, obj.currentSectionNumber);
            out = fullfile(obj.pathToSectionDirs,sectionDir);
        end %get.thisSectionDir

    end % close non-motion methods


end %close classdef