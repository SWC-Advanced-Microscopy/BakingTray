function populateCurrentTilePattern(obj,isFullPreview)
    % populate obj.currentTilePattern and obj.positionArray
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
    % Inputs
    % isFullPreview - false by default. If true, we do a preview scan over the whole
    %                 area defined by the number of x and y tiles and front/left in the
    %                 recipe. This is used to allow a preview scan even when we are in
    %                 auto-ROI mode.
    %
    % Outputs
    % None: this method updates the properties currentTilePattern and currentTilePattern
    %
    % Also see: BT.getNextROIs, runTileScan, takeRapidPreview

    if nargin<2
        isFullPreview=false;
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
        return
    end


    % This is where the stage will go. Positions in mm.
    obj.currentTilePattern=pos;


    % Here we store where the stage went. This is just a pre-allocation.
    obj.positionArray = [indexes,pos,nan(size(pos))];

    % Report to screen what's just been made
    fprintf('BT.%s populated BT.positionArray with a tile pattern of length %d\n', ...
     mfilename, size(obj.positionArray,1))

end %populateCurrentTilePattern
