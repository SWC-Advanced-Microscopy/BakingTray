classdef recipe < handle
    % recipe - The recipe class handles the settings that define an acquisition.
    %
    % Purpose
    % The recipe class stores the settings used to coordinate the acquisition of
    % a particular sample. For example, the size of the sample in X and Y, the
    % thickness of the sections, how many sections to take, the image resolution.
    % and so forth.
    %
    % The recipe class is mainly used by the BT class, to which it is attached 
    % at BT.recipe. 
    %
    %
    % Example Usage
    % Standalone usage of the recipe class is not useful for much. Nonetheless, 
    % the following are valid command-line examples:
    %
    % ONE - read the default recipe from BakingTray/SETTINGS/default_recipe.yml
    % >> R=recipe
    %  Setting sample name to: sample_17-07-10_173116
    %  R = 
    %  recipe with properties:
    %               sample: [1x1 struct]
    %               mosaic: [1x1 struct]
    %    CuttingStartPoint: [1x1 struct]
    %            FrontLeft: [1x1 struct]
    %             NumTiles: [1x1 NumTiles]
    %                 Tile: [1x1 struct]
    %         TileStepSize: [1x1 TileStepSize]
    %            VoxelSize: [1x1 struct]
    %      ScannerSettings: [1x1 struct]
    %               SYSTEM: [1x1 struct]
    %               SLICER: [1x1 struct]
    %
    % TWO - read a non-default recipe
    % >> R = recipe('Path/To/myRecipe.yml');
    %
    %
    % THREE - read an existing recipe in order to resume an acquisition
    % >> R = recipe('Path/To/myRecipe.yml', 'resume', true);
    % The difference between this and TWO is that here we re-read whatever
    % is stored in the FrontLeft and CuttingStartPoint fields (see below). 
    % Normally this is discarded. 
    %
    %
    %
    % -----------------------------------------------------------------------
    % DETAILS
    % The following information is aimed mainly at developers.
    %
    % The recipe is composed of three sets of variables:
    % 1) System-specific settings represented by upper case characters: 
    %    recipe.SYSTEM and recipe.SLICER
    %
    % 2) Derived properties that can't be edited by the user indicated by CamelCase
    %    e.g. recipe.NumTiles and recipe.TileStepSize
    %    These derived properties are handled by external helper classes. 
    %
    % 3) Settings that can be edited by the user: lower case
    %    recipe.sample and recipe.mosaic 
    %
    % If no input arguments are provided the class instantiates an object that is
    % populated by the defaults found in BakingTray/SETTINGS/default_recipe.yml
    % This directory is created the first time a recipe is built.
    %
    %
    % The default recipe YAML file contains these fields:
    %
    % sample.ID (string defining sample name)
    % sample.objectiveName (string defining objective name)
    %
    % mosaic.sectionStartNum (Integer defining the number of the first section)
    % mosaic.numSections (Integer defining the number of sections to take)
    % mosaic.cuttingSpeed (Cutting speed in mm/s)
    % mosaic.cutSize (Size of sample to cut in mm)
    % mosaic.sliceThickness (The thickness of the slice in mm)
    % mosaic.numOpticalPlanes (Integer defining the number of optical planes into which to divide each section)
    % mosaic.overlapProportion (The proportion of overlap between adjacent tiles)
    % mosaic.sampleSize.X (The extent of the sample along X in mm)
    % mosaic.sampleSize.Y (The extent of the sample along Y in mm)
    % mosaic.scanmode: (string defining the scanning mode. e.g. "tile")
    %
    % Once the sample is set up, the method recipe.writeFullRecipeForAcquisition is used
    % to record the acquisition settings as a "full" recipe file in the sample directory. 
    % This contains the above fields and also the following additional fields:
    %
    % FrontLeft.[XY] (The starting point--front left position--of the tile grid: x and y stage positions)
    % The FrontLeft is defined by the user
    %
    % CuttingStartPoint.[XY] (The point at which blade is placed in X and Y before starting to cut)
    % The CuttingStartPoint is defined by the user
    %
    % NumTiles.[XY] (The number of tiles required to cover the sample in X and Y)
    % The recipe class calculates NumTiles
    %
    % Tile.nRows - Number of image rows in each tile
    % Tile.nColumns - Number of pixels per tile
    %
    % TileStepSize.[XY] (How far the stage moves in X and Y between each tile)
    % The TileStepSize is calculated by the recipe class
    %
    % The following are records of various parameters used for the acquisition. 
    % ScannerSettings (A structure that stores a variety of information about how the scanner is configured)
    % SYSTEM and SLICER (Two structures contain the information found in the systemSettings.yml)


    properties (SetObservable, AbortSet)
        % Define legal default values for all parameters. This way it will be possible
        % to use the recipe to do *something*, even if that something isn't especially 
        % useful. 

        sample=struct('ID', '', ...           % String defining the sample name
                     'objectiveName', '16x')     % String defining the objective name

        mosaic=struct('sectionStartNum', 1, ...    % Integer defining the number of the first section (used for file name creation)
                    'numSections', 1, ...          % Integer defining how many sections to take
                    'cuttingSpeed', 0.5, ...       % Number defining how fast the blade should move through the sample (mm/s)
                    'cutSize', 20, ...             % Number defining the distance in mm to cut
                    'sliceThickness', 0.1, ...     % Number defining the thickness in mm to cut
                    'numOpticalPlanes', 2, ...     % Integer defining the number of optical planes (layers) to image
                    'overlapProportion', 0.05, ... % Value from 0 to 0.5 defining how much overlap there should be between adjacent tiles
                    'sampleSize', struct('X',1, 'Y',1), ...  % The size of the sample in mm
                    'scanmode', 'tile')            % String defining how the data are to be acquired. (e.g. "tile": tile acquisition). 


        % These properies are set via methods of BT, not directly by the user.
        % They are used for determining where to image and where to cut and aren't 
        % relevant beyond this. Cutting and imaging won't be possible until these are set to reasonable values. 
        CuttingStartPoint=struct('X',0, 'Y',0)   % Start location for cutting
        FrontLeft=struct('X',0, 'Y',0)           % Front/left position of the tile array
    end %close the main sample properties

    properties (SetAccess=protected)
        %These properties are set by the recipe class. see: 
        %  - recipe.recordScannerSettings
        %  - recipe.tilePattern
        NumTiles % Number of tiles in the grid. Calculated with an external class of the same name
        Tile=struct('nRows',0, 'nColumns',0)
        TileStepSize  % How far the stage moves in mm between tiles to four decimal places. Calculated by an external class of the same name
        VoxelSize=struct('X',0, 'Y', 0, 'Z',0);
        ScannerSettings=struct;

        % These properties are populated by structures that can be set by the user only by editing 
        % SETTINGS/systemSettings.yml this yml is made by BakingTray.Settings.readSystemSettings
        SYSTEM
        SLICER
    end %close protected properties

    properties (Hidden)
        % The acquisition property is set by other functions and isn't important to the user, so we hide it
        % NOTE: hidden properties we want to write to the recipe YAML need to be listed explicitly in 
        % recipe.writeFullRecipeForAcquisition
        Acquisition=struct('acqStartTime','')
        verbose=0;
        fname %The file name of the recipe
        parent  %A copy of the parent object (likely BakingTray) to which this component is attached

        % When the system slices, it keeps a copy in the recipe of the last slice thickness and the
        % last cutting speed. This is used as an aid in set up by the GUI to ensure that the user
        % took the last preparatory slices with the same specs as those they will image at.
        lastSliceThickness=[]
        lastCuttingSpeed=[]
    end %close hidden properties


    properties (SetAccess=protected,Hidden)
        listeners={}
    end


    % The following properties are for tasks such as GUI updating and broadasting the state of the 
    % recipe to other components.
    properties (SetObservable, AbortSet, Hidden)
        acquisitionPossible=false % Set to true if all settings indicate an acquisition is likely possible (e.g. front/left is set and so forth)
    end



    methods
        function obj=recipe(recipeFname,varargin) %Constructor

            %Parse optional arguments
            inputArgs = inputParser;
            inputArgs.CaseSensitive = false;
            inputArgs.addParameter('resume',false, @(x) islogical(x) || x==0 || x==1)
            inputArgs.parse(varargin{:});



            % Import the parameter (recipe) file
            msg='';
            if nargin<1 || isempty(recipeFname)

                % Use default recipe if the user provided none
                [params,recipeFname] = BakingTray.settings.readDefaultRecipe;

            elseif nargin>0 && ~isempty(recipeFname)

                [params,msg]=BakingTray.settings.readRecipe(recipeFname);
                if isempty(params)
                    msg=sprintf(['*** Reading of recipe %s by BakingTray.settings.readRecipe seems to have failed.\n', ...
                        '*** Using default values instead.\n'], recipeFname);
                    [params,recipeFname] = BakingTray.settings.readDefaultRecipe;
                end
                if ~isempty(msg)
                    % If we're here, there was an warning and we can carry on with the the desired recipe file
                    fprintf(msg) % Report the error
                end

            end % if nargin<1


            % Build instances of TileStepSize and NumTiles classes that will calculate these properties 
            % using dependent variables
            obj.TileStepSize = TileStepSize(obj); 
            obj.NumTiles = NumTiles(obj); 

            %Add these recipe parameters as properties
            obj.sample = params.sample;
            obj.mosaic = params.mosaic;

            if inputArgs.Results.resume
                fprintf('Retaining front/left and cutting start-point from %s\n', strrep(recipeFname,'\','\\'))
                obj.CuttingStartPoint.X = params.CuttingStartPoint.X;
                obj.CuttingStartPoint.Y = params.CuttingStartPoint.Y;
                obj.FrontLeft.X = params.FrontLeft.X;
                obj.FrontLeft.Y = params.FrontLeft.Y;
            end %if inputArgs.Results.resume


            %Add the system settings from the settings file. 
            sysSettings = BakingTray.settings.readSystemSettings;


            if isempty(sysSettings)
                error('Reading of system settings by BakingTray.settings.readSystemSettings seems to have failed')
            end

            % We do not want to ever read these settings from the recipe file. 
            obj.SYSTEM = sysSettings.SYSTEM;
            obj.SLICER = sysSettings.SLICER;

            obj.fname=recipeFname;


            %Put listeners on some of the properties and use these to update the acquisitionPossible property
            listeners{1}=addlistener(obj,'sample', 'PostSet', @obj.checkIfAcquisitionIsPossible);
            listeners{2}=addlistener(obj,'mosaic', 'PostSet', @obj.checkIfAcquisitionIsPossible);
            listeners{3}=addlistener(obj,'CuttingStartPoint', 'PostSet', @obj.checkIfAcquisitionIsPossible);
            listeners{4}=addlistener(obj,'FrontLeft', 'PostSet', @obj.checkIfAcquisitionIsPossible);

        end %Constructor


        function delete(obj)
            delete(obj.TileStepSize);
            obj.TileStepSize=[];
            delete(obj.NumTiles);
            obj.NumTiles=[];
            for ii=1:length(obj.listeners)
                delete(obj.listeners{ii})
                obj.listeners=[];
            end
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % Convenience methods
        function success=recordScannerSettings(obj)
            % Checks if a scanner object is connected to the parent (BakingTray) object and if so, 
            % run its scanner.returnScanSettings method and store the output in recipe.ScannerSettings
            if isempty(obj.parent)
                success=false;
                fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
                return
            end
            if ~isempty(obj.parent.scanner)
                obj.ScannerSettings = obj.parent.scanner.returnScanSettings;

                % Update properties related to the scanner. 
                % Some stuff will be duplicated, but is stored in a nicer format.
                % Other stuff is calculated from the scanner and recipe information
                obj.VoxelSize.X = obj.ScannerSettings.micronsPerPixel_cols;
                obj.VoxelSize.Y = obj.ScannerSettings.micronsPerPixel_rows;

                if strcmp(obj.mosaic.scanmode,'ribbon')
                    obj.VoxelSize.Z = round( (obj.mosaic.sliceThickness*1E3) / obj.mosaic.numOpticalPlanes,1);
                else
                    obj.VoxelSize.Z = obj.ScannerSettings.micronsBetweenOpticalPlanes;
                end

                obj.Tile.nRows  = obj.ScannerSettings.linesPerFrame;
                obj.Tile.nColumns = obj.ScannerSettings.pixelsPerLine;
                success=true;
            else
                success=false;
            end
        end

        function numTiles = numTilesInOpticalSection(obj)
            % Return the number of tiles to be imaged in one plane
            numTiles = obj.NumTiles.X * obj.NumTiles.Y ;
        end

        function numTiles = numTilesInPhysicalSection(obj)
            % Return the number of tiles to be imaged in one physical section
            numTiles = obj.NumTiles.X * obj.NumTiles.Y * obj.mosaic.numOpticalPlanes ;
        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % Methods for setting up the imaging scene
        function setCurrentPositionAsFrontLeft(obj)
            % recipe.setCurrentPositionAsFrontLeft
            %
            % Store the current position as the front/left of the tile grid

            % TODO: add error checks
            if isempty(obj.parent)
                success=false;
                fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
                return
            end
            hBT=obj.parent;
            [x,y]=hBT.getXYpos;
            obj.FrontLeft.X = x;
            obj.FrontLeft.Y = y;
        end % setCurrentPositionAsFrontLeft

        function setCurrentPositionAsCuttingPosition(obj)
            % recipe.setCurrentPositionAsCuttingPosition
            %
            % Store the current stage position as the position at which we will start cutting

            % TODO: add error checks
            if isempty(obj.parent)
                success=false;
                fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
                return
            end
            hBT=obj.parent;
            [x,y]=hBT.getXYpos;
            obj.CuttingStartPoint.X = x;
            obj.CuttingStartPoint.Y = y;
        end % setCurrentPositionAsCuttingPosition

        function setFrontLeftFromVentralMidLine(obj)
            % recipe.setFrontLeftFromVentralMidline
            %
            % Calculates the front-left position of sample based on the ventral mid-line.
            % The idea is that the user exposes the cerebellum until the pons is visible.
            % Then places the laser on the edge of the pons at the mid-line. If the brain
            % is straight then we can calculate the front left position given that the 
            % number of tiles in X and Y are set correctly. 
            %
            % This method sets the recipe.FrontLeft .X and .Y values. It doesn't move the stage.
            if isempty(obj.parent)
                success=false;
                fprintf('ERROR in setFrontLeftFromVentralMidLine: recipe class has nothing bound to property "parent". Can not access BT.\n')
                return
            end

            tp=obj.tilePattern;

            if isempty(tp)
                success=false;
                fprintf('ERROR in setFrontLeftFromVentralMidLine: tile position data are empty. Likely an invalid setting. Can not proceed.\n')
                return
            end

            sizeOfSample=range(tp);
            [x,y]=obj.parent.getXYpos;

            left = x+sizeOfSample(1);
            front = y+sizeOfSample(2)/2;

            obj.FrontLeft.X=left;
            obj.FrontLeft.Y=front;
        end % setFrontLeftFromVentralMidLine

        function estimatedSizeInGB = estimatedSizeOnDisk(obj)
            % recipe.estimatedSizeOnDisk
            %
            % Return the estimated size of of the acquisition on disk in gigabytes
            if ~obj.parent.isScannerConnected
                fprintf('No scanner connected. Can not estimate size on disk\n')
                estimatedSize=nan;
                return
            end

            N=obj.NumTiles;
            imagesPerChannel = obj.mosaic.numOpticalPlanes * obj.mosaic.numSections * N.X * N.Y;
            
            scnSet = obj.ScannerSettings;
            totalImages = imagesPerChannel * length(scnSet.activeChannels);

            totalBytes = totalImages * scnSet.pixelsPerLine * scnSet.linesPerFrame * 2; %2 bytes per pixel (16 bit)

            totalBytes = totalBytes *1.01; % Add 1% for headers and so forth

            estimatedSizeInGB = totalBytes/1024^3;

        end % estimatedSizeOnDisk

    end %methods




    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    %Getters and setters
    methods

        % Setter for the recipe.sample structure. 
        % This is used to ensure that the values entered by the user are valid
        function obj = set.sample(obj,val)
            oldVal = obj.sample; % store the previous values
            theseFields = fields(oldVal);

            %If we're acquiring data, don't change anything
            if ~isempty(obj.parent) && obj.parent.acquisitionInProgress
                return
            end

            for fn = theseFields(:)' % loop through fields to check what has changed
                if ~isstruct(val)
                    % The user is trying to assign something directly to sample
                    return
                end

                field2check = fn{1};
                fieldValue=val.(field2check);
                if isfield(val,field2check)
                    switch field2check
                        case 'ID'
                            if ischar(fieldValue)
                                % Generate a base file name for the sample, replacing or removing unusual characters
                                % This is to ensure the user can't make up silly names that cause problems down the line.
                                fieldValue = regexprep(fieldValue, ' ', '_');
                                fieldValue = regexprep(fieldValue, '[^0-9a-z_A-Z-]', '');
                                if length(fieldValue)>0
                                    if regexp(fieldValue(1),'\d')
                                        %Do not allow sample name to start with a number
                                        fieldValue = ['sample_',fieldValue];
                                    elseif regexpi(fieldValue(1),'[^a-z]')
                                        %Do not allow the sample to start with something that isn't a letter
                                        fieldValue = ['sample_',fieldValue(2:end)];
                                    end
                                end
                            end

                            % If the sample name is not a string or empty then we just make one up
                            if ~ischar(fieldValue) || length(fieldValue)==0
                                fieldValue=['sample_',datestr(now,'yymmdd_HHMMSS')];
                                fprintf('Setting sample name to: %s\n',fieldValue)
                            end
                            obj.sample.(field2check) = fieldValue;

                          case 'objectiveName'
                            if ischar(fieldValue)
                                obj.sample.(field2check) = fieldValue;
                            else
                                fprintf('ERROR: sample.objectiveName must be a string!\n')
                            end
                    end % switch
               end % if isfield
            end
        end % set.sample



        % Setter for the recipe.mosaic structure. 
        % This is used to ensure that the values entered by the user are valid
        function obj = set.mosaic(obj,val)
            oldVal = obj.mosaic; % store the previous values
            theseFields = fields(oldVal);

            % If we're acquiring data, don't change anything
            if ~isempty(obj.parent) && obj.parent.acquisitionInProgress
                return
            end


            for fn = theseFields(:)' % loop through fields to check what has changed
                field2check = fn{1};
                if ~isstruct(val)
                    % The user is trying to assign something directly to mosaic
                    return
                end
                fieldValue=val.(field2check);
                if isfield(val,field2check)
                    switch field2check

                        case 'scanmode'
                            if ischar(fieldValue)
                                % Pass - the value will be assigned at the end of the method
                            else
                                fprintf('ERROR: mosaic.scanmode must be a string!\n')
                                fieldValue=[]; %Will stop. the assignment from happening
                            end
                            if ~strcmp(fieldValue,'tile') && ~strcmp(fieldValue,'ribbon')
                                fprintf('ERROR: mosaic.scanmode can only be set to "tile" or "ribbon"\n')
                                fieldValue=[]; % As above, will stop the assignment.
                            end

                        case 'sectionStartNum'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'numSections'
                            fieldValue = obj.checkInteger(fieldValue);

                            if ~isempty(fieldValue) && isnumeric(fieldValue) && ~isempty(obj.parent) && isvalid(obj.parent) && isa(obj.parent,'BT') && obj.parent.isZaxisConnected
                                %Ensure there is enough Z motion range to accomodate this many sections
                                distanceAvailable = obj.parent.zAxis.getMaxPos - obj.parent.zAxis.axisPosition;  %more positive is a more raised Z platform
                                distanceRequested = fieldValue * obj.mosaic.sliceThickness;

                                if distanceRequested>distanceAvailable
                                    numSlicesPossible = floor(distanceAvailable/obj.mosaic.sliceThickness)-1;
                                    fprintf(['Requested %d slices: this is %0.2f mm thick but only %0.2f mm is possible. ',...
                                        'You can cut a maximum of %d slices.\n'], ...
                                     fieldValue,...
                                     distanceRequested, ...
                                     distanceAvailable,...
                                     numSlicesPossible);
                                    fieldValue = numSlicesPossible;
                                end
                            end % if ~isempty(fieldValue) ...

                        case 'cuttingSpeed'
                            fieldValue = obj.checkFloat(fieldValue,0.05,2); %min/max allowed speeds
                        case 'cutSize'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'sliceThickness'
                            fieldValue = obj.checkFloat(fieldValue,0.01,1); %Allow slices up to 1 mm thick
                        case 'numOpticalPlanes'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'overlapProportion'
                            fieldValue = obj.checkFloat(fieldValue,0,0.5); %Overlap allowed up to 50%
                        case 'sampleSize'
                            % TODO: in fact, this should be larger than the tile size but we carry on like this for now
                            if ~isstruct(fieldValue)
                                fieldValue=[];
                            else 
                                % Do not allow the sample size to be smaller than the tile size
                                if obj.TileStepSize.X==0
                                    minSampleSizeX=0.05;
                                else
                                    minSampleSizeX=obj.TileStepSize.X;
                                end

                                if obj.TileStepSize.Y==0
                                    minSampleSizeY=0.05;
                                else
                                    minSampleSizeY=obj.TileStepSize.Y;
                                end

                                fieldValue.X = obj.checkFloat(fieldValue.X, minSampleSizeX, 20);
                                fieldValue.Y = obj.checkFloat(fieldValue.Y, minSampleSizeY, 20);
                                if isempty(fieldValue.X) || isempty(fieldValue.Y)
                                    fieldValue=[];
                                end
                            end
                        otherwise
                            fprintf('ERROR in recipe class: unknown field: %s\n',field2check)
                            fieldValue=[];
                    end % switch

                    % Values that aren't empty are deemed valid and assigned
                    if ~isempty(fieldValue)
                        obj.mosaic.(field2check) = fieldValue;
                    end

               end %if isfield
            end
        end % set.mosaic


        % Setter for the recipe.FrontLeft structure. 
        % This is used to ensure that the values entered by the user are valid
        function obj = set.FrontLeft(obj,val)

            % If we're acquiring data, don't change anything
            if ~isempty(obj.parent) && obj.parent.acquisitionInProgress
                return
            end

            % If the recipe is attached to nothing we just set the values to whatever the user asked for
            if isempty(obj.parent)
                obj.FrontLeft.X = val.X;
                obj.FrontLeft.Y = val.Y;
                return
            end

            oldVal = obj.FrontLeft; % store the previous values

            val.X = obj.checkFloat(val.X, obj.parent.xAxis.attachedStage.minPos, obj.parent.xAxis.attachedStage.maxPos);
            val.Y = obj.checkFloat(val.Y, obj.parent.yAxis.attachedStage.minPos, obj.parent.yAxis.attachedStage.maxPos);

            if isempty(val.X)
                val.X = oldVal.X;
            end

            if isempty(val.Y)
                val.Y = oldVal.Y;
            end

            obj.FrontLeft.X = val.X;
            obj.FrontLeft.Y = val.Y;
        end % set.FrontLeft


        % Setter for the recipe.CuttingStartPoint structure. 
        % This is used to ensure that the values entered by the user are valid
        function obj = set.CuttingStartPoint(obj,val)

            % If we're acquiring data, don't change anything
            if ~isempty(obj.parent) && obj.parent.acquisitionInProgress
                return
            end

            % If the recipe is attached to nothing we just set the values to whatever the user asked for
            if isempty(obj.parent)
                obj.CuttingStartPoint.X = val.X;
                obj.CuttingStartPoint.Y = val.Y;
                return
            end

            oldVal = obj.CuttingStartPoint; % store the previous values

            val.X = obj.checkFloat(val.X, obj.parent.xAxis.attachedStage.minPos, obj.parent.xAxis.attachedStage.maxPos);
            val.Y = obj.checkFloat(val.Y, obj.parent.yAxis.attachedStage.minPos, obj.parent.yAxis.attachedStage.maxPos);

            if isempty(val.X)
                val.X = oldVal.X;
            end

            if isempty(val.Y)
                val.Y = oldVal.Y;
            end

            obj.CuttingStartPoint.X = val.X;
            obj.CuttingStartPoint.Y = val.Y;
        end % set.FrontLeft


    end %methods: getters/setters

    methods (Hidden)
        % Convenience methods that aren't methods
        function value=checkInteger(~,value)
            % Confirm that an input is a positive integer
            % Returns empty if the input is not valid. 
            % Empty values aren't assigned to a property by the setters
            if ~isnumeric(value) || ~isscalar(value)
                value=[];
                return
            end

            if value<=0
                value=[];
                return
            end

            value = ceil(value);
        end %checkInteger

        function value=checkFloat(~,value,minVal,maxVal)
            % Confirm that an input is a positive float no smaller than minVal and 
            % no larger than maxVal. Returns empty if the input is not valid. 
            % Empty values aren't assigned to a property by the setters
            if nargin<3
                maxVal=inf;
            end
            if ~isnumeric(value) || ~isscalar(value)
                value=[];
                return
            end

            if value<minVal
                value=minVal;
                return
            end
            if value>maxVal
                value=maxVal;
                return
            end
        end % checkFloat

        function checkIfAcquisitionIsPossible(obj,~,~)
            % Check if it will be possible to acquire data based on the current recipe settings
            if isempty(obj.FrontLeft.X) || isempty(obj.FrontLeft.Y) || ...
                isempty(obj.CuttingStartPoint.X) || isempty(obj.CuttingStartPoint.Y) || ...
                isempty(obj.mosaic.sampleSize.X) || isempty(obj.mosaic.sampleSize.Y)
                obj.acquisitionPossible=false;
                return
            end

            if isempty(obj.sample.ID)
                obj.acquisitionPossible=false;
                return
            end

            % The front left position needs to be *at least* the thickness of a cut from the 
            % blade plus half the X width of the specimen. This doesn't even account for
            % the agar, etc. So it's a very relaxed criterion. 
            if obj.SYSTEM.cutterSide==1
                if (obj.FrontLeft.X+obj.mosaic.sampleSize.X) < obj.CuttingStartPoint.X
                    obj.acquisitionPossible=true;
                else
                    obj.acquisitionPossible=false;
                end
            elseif obj.SYSTEM.cutterSide==-1
                % This scenario has never been tested with physical hardware
                if obj.FrontLeft.X>obj.CuttingStartPoint.X
                    obj.acquisitionPossible=true;
                else
                    obj.acquisitionPossible=false;
                end
            end

        end % checkIfAcquisitionIsPossible

    end % Hidden methods

end