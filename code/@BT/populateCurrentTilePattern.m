function varargout=populateCurrentTilePattern(obj,varargin)
    % populate the x/y tile pattern at obj.currentTilePattern and obj.positionArray
    %
    % Purpose
    % The positions sampled during an acquisition by a tile scan are stored in advance in
    % the property obj.currentTilePattern. The locations to which the stage actually went
    % are stored in obj.positionArray. This method populates obj.currentTilePattern and
    % pre-allocates obj.positionArray according to the acquisition mode. The acquisition
    % mode is stored in obj.recipe.mosaic.scanmode and is set by the user:
    %
    % * 'tiled: manual ROI' means a single FOV drawn by the user.
    %
    % * 'tiled: auto-ROI' means one or more FOVs calculated by autoROI.m
    %  The auto-ROI uses obj.autoROI.stats.roiStats(end).BoundingBoxDetails
    %
    %
    % Inputs (optional param/val pairs)
    % isFullPreview - false by default. If true, we do a preview scan over the whole
    %                 area defined by the number of x and y tiles and front/left in the
    %                 recipe. This is used to allow a preview scan even when we are in
    %                 auto-ROI mode.
    % 'keepTiles' - empty by default. If provided, the current tile pattern is calculated
    %               and only these tile indexes are kept. (supply a vector to use)
    % 'removeTiles' - empty by default. If provided, the current tile pattern is calculated
    %               and these tiles index values are removed. The argument is supplied as a 
    %               vector so to remove the first and last tiles of a tile pattern having 
    %               length 256 you would supply [1,256] as the value for this parameter.
    %
    % Outputs
    % pos - The tile pattern. This is returned to make it easier to confirm
    %       what was generated. 
    % NOTE:
    % a) You can not supply both keepTiles and removeTiles. 
    % b) The keepTiles and removeTiles arguments are currently not used for anything and are
    %    present for possible future use only.
    % c) see also recipe.mosaic.tilesToRemove, which is honoured in recipe.tilePattern
    %
    %
    % Outputs
    % None: this method updates the properties currentTilePattern and currentTilePattern
    %
    % Also see: BT.getNextROIs, runTileScan, takeRapidPreview


    % Parse optional inputs
    P = inputParser;
    P.CaseSensitive = false;
    P.addParameter('isFullPreview',false)
    P.addParameter('removeTiles',[])
    P.addParameter('keepTiles', [])

    P.parse(varargin{:})

    isFullPreview = P.Results.isFullPreview;
    removeTiles = P.Results.removeTiles;
    keepTiles = P.Results.keepTiles;

    if ~isempty(removeTiles) && ~isempty(keepTiles)
        error('Can not supply both removeTiles and keepTiles');
    end



    pos=[]; % In case for whatever reason no tile pattern is generated. During an acquisition
            % this won't be a problem.

    if isFullPreview
        [pos,indexes]=obj.recipe.tilePattern;

    elseif strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI') && ...
            ~isempty(obj.autoROI) && ...
            isfield(obj.autoROI,'stats')

        BB = obj.autoROI.stats.roiStats(end).BoundingBoxDetails;
        [pos,indexes]=obj.recipe.tilePattern(false,false,BB);

    elseif strcmp(obj.recipe.mosaic.scanmode,'tiled: manual ROI')
        % Manual ROI
        [pos,indexes]=obj.recipe.tilePattern;
    end

    if isempty(pos)
        fprintf('No tile pattern was generated in BT.populateCurrentTilePattern\n');
        if nargout>0
            varargout=pos;
        end
        return
    end

    % Modify tile pattern as appropriate
    if ~isempty(removeTiles)
        pos(removeTiles,:)=[];
        indexes(removeTiles,:)=[];
    elseif ~isempty(keepTiles)
        pos = pos(keepTiles,:);
        indexes = indexes(keepTiles,:);
    end

    % This is where the stage will go. Positions in mm.
    obj.currentTilePattern=pos;


    % Here we store where the stage went. This is just a pre-allocation.
    obj.positionArray = [indexes,pos,nan(size(pos))];

    % Report to screen what's just been made
    fprintf('BT.%s populated BT.positionArray with a tile pattern of length %d\n', ...
     mfilename, size(obj.positionArray,1))
    
    if nargout>0
        varargout=pos;
    end
end %populateCurrentTilePattern
