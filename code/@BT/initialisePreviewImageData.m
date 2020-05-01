function initialisePreviewImageData(obj,tp)
    % Generate empty preview stack and tile position coordinates.
    %
    % Purpose
    % Calculate where the tiles will go in the preview image the create the image
    % if the tile pattern (output of the recipe tilePattern method) is not supplied
    % then it is obtained here. 
    % The preview image is stored in obj.lastPreviewImageStack. Anything in there
    % before running this method is wiped out.
    %
    % 

    if nargin<2
        tp=obj.recipe.tilePattern; %Stage positions in mm (x,y)
    end


    if isempty(tp)
        fprintf('ERROR: no tile position data. BT.initialisePreviewImageData can not build empty image\n')
        return
    end

    % First we initialise the image

    % The size of the preview image
    % Potential Bug:  The following is correct with square tiles. It may be wrong with rectangular tiles.
    %                 Not tested with rectangular tiles.
    stepSizes(1) = getTileSizeFromPositionList(tp(:,1));
    stepSizes(2) = getTileSizeFromPositionList(tp(:,2));

    ovLap = 1-obj.recipe.mosaic.overlapProportion;
    %              imsize + tile size including overlap
    rangeAlongColsInMM = range(tp(:,2)) + (stepSizes(1) * ovLap);
    imCols = round(rangeAlongColsInMM / (obj.downsampleMicronsPerPixel * 1E-3) );
    rangeAlongRowsInMM = range(tp(:,1)) + (stepSizes(2) * ovLap);
    imRows = round(rangeAlongRowsInMM / (obj.downsampleMicronsPerPixel * 1E-3) );

    obj.lastPreviewImageStack = zeros([imRows,imCols, ...
        obj.recipe.mosaic.numOpticalPlanes, ...
        obj.scanner.maxChannelsAvailable],'int16');% * -2E15; % TODO -- add this back in for SIBT?
                                                              % TODO -- add pi so we can remove later?



    % Log the current front/left position from the recipe
    obj.frontLeftWhenPreviewWasTaken.X = obj.recipe.FrontLeft.X;
    obj.frontLeftWhenPreviewWasTaken.Y = obj.recipe.FrontLeft.Y;


    % Convert to pixels
    pos = round(obj.convertStagePositionToImageCoords(tp));
    pos(pos==0)=1;
    obj.previewTilePositions = fliplr(pos);


    % Wipe any data in the down-sampled tile buffer
    obj.downSampledTileBuffer(:)=0;


    if nargin<2
        fprintf('Initialised a preview image of %d columns by %d rows using BT.recipe.tilePattern.\n', imCols, imRows)
    else
        fprintf('Initialised a preview image of %d columns by %d rows using supplied tile positions.\n', imCols, imRows)
    end
end %initialisePreviewImageData



    function tSize = getTileSizeFromPositionList(pList)
        % pList is a list of X or Y stage or pixel positions
        % from this we obtain the tile size as the largest 
        % most common interval between tiles
        d = diff(pList);
        d(d==0) = [];
        tSize = mode(abs(d));
    end