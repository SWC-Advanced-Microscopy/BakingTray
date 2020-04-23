function initialisePreviewImageData(obj,tp)
    % Calculate where the tiles will go in the preview image the create the image
    % if the tile pattern (output of the recipe tilePattern method) is not supplied
    % then it is obtained here. 

    if nargin<2
        tp=obj.model.recipe.tilePattern; %Stage positions in mm (x,y)
    end

    if isempty(tp)
        fprintf('ERROR: no tile position data. initialisePreviewImageData can not build empty image\n')
        return
    end
    tp(:,1) = tp(:,1) - tp(1,1);
    tp(:,2) = tp(:,2) - tp(1,2);


    tp=abs(tp);
    tp=ceil(tp/obj.model.downsampleTileMMperPixel);
    obj.previewTilePositions=tp;

    ovLap = obj.model.recipe.mosaic.overlapProportion+1;

    % The size of the preview image
    stepSizes = max(abs(diff(tp)));
    %              imsize + tile size including overlap
    imCols = range(tp(:,1)) + round(stepSizes(1) * ovLap);
    imRows = range(tp(:,2)) + round(stepSizes(2) * ovLap);


    obj.previewImageData = ones([imRows,imCols, ...
        obj.model.recipe.mosaic.numOpticalPlanes, ...
        obj.model.scanner.maxChannelsAvailable],'int16') * -2E15;

    obj.model.downSampledTileBuffer(:)=0;

    if ~isempty(obj.sectionImage)
        obj.sectionImage.CData(:)=0;
    end

    % Log the current front/left position from the recipe
    obj.frontLeftWhenPreviewWasTaken.X = obj.model.recipe.FrontLeft.X;
    obj.frontLeftWhenPreviewWasTaken.Y = obj.model.recipe.FrontLeft.Y;

    fprintf('Initialised a preview image of %d columns by %d rows\n', imCols, imRows)
end %initialisePreviewImageData
