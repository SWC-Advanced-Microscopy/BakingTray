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
    %  StitchingParameters: []
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
    % CuttingStartPoint.[XY] (The point at which blade is placed in X and Y before starting to cut)
    % The CuttingStartPoint is defined by the user
    %
    % FrontLeft.[XY] (The starting point--front left position--of the tile grid: x and y stage positions)
    % The FrontLeft is defined by the user
    %
    % StitchingParameters (The images will be stitched using parameters in this structure)
    % The stitching parameters aren't used by BakingTray but by StitchIt
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
    % VoxelSize.[XY] (The nominal voxel size returned by the scanner)
    %
    % The following are records of various parameters used for the acquisition.
    % ScannerSettings (A structure that stores a variety of information about how the scanner is configured. see recipe.recordScannerSettings)
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
                    'numOverlapZPlanes', 0, ...   % Number of extra optical planes to add. Allows for z overlap in a slightly crappy way.
                    'numOpticalPlanes', 2, ...     % Integer defining the number of optical planes (layers) to image
                    'overlapProportion', 0.05, ... % Value from 0 to 0.5 defining how much overlap there should be between adjacent tiles
                    'sampleSize', struct('X',1, 'Y',1), ...  % The size of the sample in mm
                    'scanmode', 'tile', ... % String defining how the data are to be acquired.
                    'tilesToRemove', -1) %vector defining which tile locations from the grid will be skipped. -1 means all are imaged


        % These properies are set via methods of BT, not directly by the user.
        % They are used for determining where to image and where to cut and aren't
        % relevant beyond this. Cutting and imaging won't be possible until these are set to reasonable values.
        CuttingStartPoint=struct('X',NaN, 'Y',0)   % Start location for cutting
        FrontLeft=struct('X',NaN, 'Y',0)           % Front/left position of the tile array


        StitchingParameters
    end %close the main sample properties

    properties (SetAccess=protected)
        %These properties are set by the recipe class. see:
        %  - recipe.recordScannerSettings
        %  - recipe.tilePattern
        NumTiles % Number of tiles in the grid. Calculated with an external class of the same name

        % The "Tile" structure defines the number of tile rows and columns in the final tile grid.
        % This is used if the user has selected "tiled: Manual ROI". It's ignored in autoROI.
        % If the vector "tilesToRemove" is supplied, then these tiles are removed from the grid and
        % not imaged.
        Tile=struct('nRows',0, 'nColumns',0)
        TileStepSize  % How far the stage moves in mm between tiles to four decimal places. Calculated by an external class of the same name
        VoxelSize=struct('X',0, 'Y', 0, 'Z',0);
        ScannerSettings=struct;

        % These properties are populated by structures that can be set by the user only by editing
        % SETTINGS/systemSettings.yml this yml is made by BakingTray.Settings.readSystemSettings
        SYSTEM
        SLACK
    end %close protected properties

    properties
        % Slicer is here so we can easily change things like vibrate rate if needed
        SLICER
    end

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

        % These are the valid possibilities for the scan mode. We place them here
        % as a property so the main GUI can query the valid values and use this to
        % building a drop-down menu.
        valid_scanMode_values = {'tiled: manual ROI','tiled: auto-ROI'};
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
            obj.sample = []; % Declare only to maintain a nice order for the fields
            obj.mosaic = params.mosaic;

            %Add the system settings from the settings file.
            sysSettings = BakingTray.settings.readSystemSettings;


            if isempty(sysSettings)
                error('Reading of system settings by BakingTray.settings.readSystemSettings seems to have failed')
            end

            % We do not want to ever read these settings from the recipe file.
            obj.SYSTEM = sysSettings.SYSTEM;
            obj.SLICER = sysSettings.SLICER;
            obj.SLACK = sysSettings.SLACK;

            obj.sample = params.sample; % Can now fill this in: it required the SYSTEM field to be present.
            obj.fname=recipeFname;


            if inputArgs.Results.resume
                fprintf('Retaining front/left and cutting start-point from %s\n', strrep(recipeFname,'\','\\'))
                obj.CuttingStartPoint.X = params.CuttingStartPoint.X;
                obj.CuttingStartPoint.Y = params.CuttingStartPoint.Y;
                obj.FrontLeft.X = params.FrontLeft.X;
                obj.FrontLeft.Y = params.FrontLeft.Y;
            else
                %otherwise use a position near the slide front/left
                obj.FrontLeft.X = obj.SYSTEM.slideFrontLeft{1}-2;
                obj.FrontLeft.Y = obj.SYSTEM.slideFrontLeft{2}-2;

                %and the default Y start point
                obj.CuttingStartPoint.Y = obj.SLICER.defaultYcutPos; % Set to value in settings file
            end %if inputArgs.Results.resume



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
        function numTiles = numTilesInOpticalSection(obj)
            % Return the number of tiles to be imaged in one plane
            %
            % If we are doing a manual ROI, this is the product of the number of
            % tiles in X and Y. If this is an auto-ROI, the result is the number
            % of rows in BT.currentTilePattern. Of course that means one must have
            % have updated the current tile pattern before running this!
            if strcmp(obj.mosaic.scanmode,'tiled: auto-ROI')
                numTiles = size(obj.parent.currentTilePattern,1);
            elseif strcmp(obj.mosaic.scanmode,'tiled: manual ROI')
                numTiles = obj.NumTiles.X * obj.NumTiles.Y ;
            end
        end %numTilesInOpticalSection

        function numTiles = numTilesInPhysicalSection(obj)
            % Return the number of tiles to be imaged in one physical section
            numTiles = obj.numTilesInOpticalSection * obj.mosaic.numOpticalPlanes ;
        end %numTilesInPhysicalSection


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
                            sampleNameStem = obj.SYSTEM.ID; %The sample name will always start with the system name
                            if strcmp(sampleNameStem,'SYSTEM_NAME')
                                sampleNameStem = 'BrainSawSample';
                            end
                            if ~endsWith(sampleNameStem,'_')
                                sampleNameStem = [sampleNameStem,'_'];
                            end
                            if ischar(fieldValue)
                                if length(fieldValue)>0
                                    if regexp(fieldValue(1),'\d')
                                        %Do not allow sample name to start with a number
                                        fieldValue = [sampleNameStem,fieldValue];
                                    elseif regexpi(fieldValue(1),'[^a-z]')
                                        %Do not allow the sample to start with something that isn't a letter
                                        fieldValue = [sampleNameStem,fieldValue(2:end)];
                                    end
                                end
                            end

                            % If the sample name is not a string or empty then we just make one up
                            if ~ischar(fieldValue) || length(fieldValue)==0
                                fieldValue=[sampleNameStem,datestr(now,'yymmdd_HHMMSS')];
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

                            % TODO: temporary hack just in case. Remove once we have deployed a
                            % a functioning auto-ROI
                            if strcmp(fieldValue,'tile')
                                fieldValue = 'tiled: manual ROI';
                            end

                            if isempty(strmatch(fieldValue,obj.valid_scanMode_values))
                                fprintf('ERROR: mosaic.scanmode can only be set to one of the following values:\n')
                                cellfun(@(x) fprintf(' *  %s\n',x),obj.valid_scanMode_values)
                                fprintf('\n')
                                fieldValue=[]; % As above, will stop the assignment.
                            end

                        case 'tilesToRemove'
                            if isnumeric(fieldValue) && isvector(fieldValue)
                                %pass
                            elseif isempty(fieldValue)
                                fieldValue=-1;
                            else
                                fprintf('ERROR: mosaic.tilesToRemove must be empty or a numeric vector!\n')
                                fieldValue=-1;
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
                                        'Setting to the maximum value of %d slices.\n'], ...
                                     fieldValue,...
                                     distanceRequested, ...
                                     distanceAvailable,...
                                     numSlicesPossible);
                                    fieldValue = numSlicesPossible;
                                end
                            end % if ~isempty(fieldValue) ...

                        case 'cuttingSpeed'
                            fieldValue = obj.checkFloat(fieldValue,0.05,0.75); %min/max allowed speeds
                        case 'cutSize'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'sliceThickness'
                            fieldValue = obj.checkFloat(fieldValue,0.01,1); %Allow slices up to 1 mm thick
                        case 'numOverlapZPlanes'
                            fieldValue = obj.checkInteger(fieldValue,true);
                        case 'numOpticalPlanes'
                            fieldValue = obj.checkInteger(fieldValue);
                        case 'overlapProportion'
                            fieldValue = obj.checkFloat(fieldValue,0,0.5); %Overlap allowed up to 50%
                        case 'sampleSize'
                            % The minimum sample size in one tile step size
                            if ~isstruct(fieldValue)
                                fieldValue=[];
                            else
                                % Do not allow the sample size to be smaller than the tile size.
                                % This is a little weirdly written here, but it works.
                                tileX = obj.TileStepSize.X;
                                if tileX==0
                                    minSampleSizeX=0.05;
                                else
                                    minSampleSizeX=tileX;
                                end

                                tileY = obj.TileStepSize.Y;
                                if tileY==0
                                    minSampleSizeY=0.05;
                                else
                                    minSampleSizeY=tileY;
                                end

                                % The maximum size of the sample is *hard-coded* here
                                fieldValue.X = obj.checkFloat(fieldValue.X, minSampleSizeX, 40);
                                fieldValue.Y = obj.checkFloat(fieldValue.Y, minSampleSizeY, 29);
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
        % Convenience methods
        function value=checkInteger(~,value,allowZero)
            % Confirm that an input is a positive integer
            % Returns empty if the input is not valid.
            % Empty values aren't assigned to a property by the setters
            if nargin<3
                allowZero=false;
            end
            if ~isnumeric(value) || ~isscalar(value)
                value=[];
                return
            end

            if allowZero==false && value<=0
                value=[];
                return
            end

            value = ceil(value);
        end %checkInteger

        function value=checkFloat(~,value,minVal,maxVal)
            % Confirm that an input is a positive float no smaller than minVal and
            % no larger than maxVal. Returns empty if the input is not valid.
            % Empty values aren't assigned to a property by the setters.
            % Store to acccuracy of five decimal places
            if nargin<3
                maxVal=inf;
            end
            if ~isnumeric(value) || ~isscalar(value)
                value=[];
                return
            end

            value = round(value,5);
            if value<minVal
                value=minVal;
                return
            end
            if value>maxVal
                value=maxVal;
                return
            end
        end % checkFloat
    end % Hidden methods

end
