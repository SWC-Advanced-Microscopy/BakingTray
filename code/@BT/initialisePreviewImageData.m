function initialisePreviewImageData(obj,tp)
    % Calculate where the tiles will go in the preview image the create the image
    % if the tile pattern (output of the recipe tilePattern method) is not supplied
    % then it is obtained here. 
    % The preview image is stored in obj.lastPreviewImageStack. Anything in there
    % before running this method is wiped out.

    if nargin<2
        tp=obj.recipe.tilePattern; %Stage positions in mm (x,y)
    end



    if isempty(tp)
        fprintf('ERROR: no tile position data. BT.initialisePreviewImageData can not build empty image\n')
        return
    end

    % Conver to pixels
    % TODO - can BT.convertStagePositionToImageCoords do this?
    tp(:,1) = tp(:,1) - tp(1,1);
    tp(:,2) = tp(:,2) - tp(1,2);


    tp=abs(tp);
    tp=ceil(tp/ (obj.downsampleMicronsPerPixel*1E-3) );
    obj.previewTilePositions=tp;

    ovLap = obj.recipe.mosaic.overlapProportion+1;

    % The size of the preview image
    stepSizes = max(abs(diff(tp)));
    %              imsize + tile size including overlap
    imCols = range(tp(:,2)) + round(stepSizes(1) * ovLap); % CHANGE -- TODO CONFIRM AUTOROI
    imRows = range(tp(:,1)) + round(stepSizes(2) * ovLap); % CHANGE -- TODO CONFIRM AUTOROI


    obj.lastPreviewImageStack = ones([imRows,imCols, ...
        obj.recipe.mosaic.numOpticalPlanes, ...
        obj.scanner.maxChannelsAvailable],'int16') * -2E15;

    obj.downSampledTileBuffer(:)=0;

    % Log the current front/left position from the recipe
    obj.frontLeftWhenPreviewWasTaken.X = obj.recipe.FrontLeft.X;
    obj.frontLeftWhenPreviewWasTaken.Y = obj.recipe.FrontLeft.Y;

    if nargin<2
        fprintf('Initialised a preview image of %d columns by %d rows using BT.recipe.tilePattern.\n', imCols, imRows)
    else
        fprintf('Initialised a preview image of %d columns by %d rows using supplied tile positions.\n', imCols, imRows)
    end
end %initialisePreviewImageData
