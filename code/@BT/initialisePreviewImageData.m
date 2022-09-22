function success = initialisePreviewImageData(obj,tp,frontLeft)
    % Generate empty preview stack and tile position coordinates.
    %
    % Purpose
    % Calculate where the tiles will go in the preview image the create the image
    % if the tile pattern (output of the recipe tilePattern method) is not supplied
    % then it is obtained here. 
    % The preview image is stored in obj.lastPreviewImageStack. Anything in there
    % before running this method is wiped out.
    %
    % Inputs 
    % tp - the tile pattern
    % frontLeft - the front/left position (empty be default) if supplied the tile
    %             pattern is positioned in the specified location. Otherwise the
    %             position of the pattern is determined by the function. 
    %
    % Outputs
    % success - if true the preview stack was initialised. false otherwise.
    %
    %

    verbose=true;
    success = false;
    if nargin<2
        tp=obj.recipe.tilePattern; %Stage positions in mm (x,y)
    end

    if nargin<3
        frontLeft=[];
    end

    if isempty(tp)
        fprintf('ERROR: no tile position data. BT.initialisePreviewImageData can not build empty image\n')
        return
    end

    % First we initialise the image

    % The size of the preview image
    % Potential Bug:  The following is correct with square tiles. It may be wrong with rectangular tiles.
    %                 Not tested with rectangular tiles.
    stepSizesMM(1) = getTileSizeFromPositionList(tp(:,1));
    stepSizesMM(2) = getTileSizeFromPositionList(tp(:,2));

    ovLap = 1-obj.recipe.mosaic.overlapProportion;
    %              imsize + tile size including overlap
    rangeAlongColsInMM = range(tp(:,2)) + (stepSizesMM(1)/ovLap);
    imCols = round(rangeAlongColsInMM / (obj.downsampleMicronsPerPixel * 1E-3) );

    rangeAlongRowsInMM = range(tp(:,1)) + (stepSizesMM(2)/ovLap);
    imRows = round(rangeAlongRowsInMM / (obj.downsampleMicronsPerPixel * 1E-3) );

    if isnan(imCols) || isnan(imRows)
        fprintf('Preview image stack is smaller than minimum size.\n')
        fprintf('initialisePreviewImageData is not generating a blank preview\n')
        return
    end

    % The above if statement should clear up crashes but just in case we for now
    % keep the try/catch (14/02/2022)
    try
        obj.lastPreviewImageStack = zeros([imRows,imCols, ...
            obj.recipe.mosaic.numOpticalPlanes + obj.recipe.mosaic.numOverlapZPlanes, ...
            obj.scanner.maxChannelsAvailable],'int16');
    catch ME

        fprintf('Failed to make preview image stack!\n')
        disp('imRows:')
        disp(imRows)
        disp('imCols:')
        disp(imCols)
        disp('tp:')
        disp(tp)
        disp(ME.message)
        return
    end


    % Log the current front/left position from the recipe. This must be done at this point
    % because BT.convertStagePositionToImageCoords uses this value to calculate where the tiles 
    % should be placed
    if ~isempty(frontLeft)
        % pass
        if verbose
            fprintf('%s front/left supplied. Not updating BT.frontLeftWhenPreviewWasTaken\n',mfilename)
        end
    elseif strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
        frontLeft.X = max(tp(:,1)); %This is the left-most part of all the ROIs
        frontLeft.Y = max(tp(:,2)); %This is the nearest part of all the ROIs
        if verbose
            fprintf('%s is in auto-ROI mode. It updates BT.frontLeftWhenPreviewWasTaken',mfilename)
            if ~isempty(obj.frontLeftWhenPreviewWasTaken.X)
                fprintf(':\n  X: %0.2f --> %0.2f\n', obj.frontLeftWhenPreviewWasTaken.X, frontLeft.X)
                fprintf('  Y: %0.2f --> %0.2f\n', obj.frontLeftWhenPreviewWasTaken.Y, frontLeft.Y)
            else
                fprintf('\n')
            end
        end
        obj.frontLeftWhenPreviewWasTaken = frontLeft;
    elseif strcmp(obj.recipe.mosaic.scanmode,'tiled: manual ROI')
        frontLeft.X = obj.recipe.FrontLeft.X;
        frontLeft.Y = obj.recipe.FrontLeft.Y;
        obj.frontLeftWhenPreviewWasTaken = frontLeft;
        if verbose
            fprintf('%s updated BT.frontLeftWhenPreviewWasTaken and is in manual ROI mode\n',mfilename)
        end
    else
        fprintf('%s: no frontLeft provided and scan mode is unknown\n. This should not happen',mfilename)
    end

    % Convert to pixels
    if verbose
        fprintf('%s is getting tile positions using front-left value: x=%0.2f y=%0.2f\n', ...
            mfilename, frontLeft.X, frontLeft.Y)
    end

    % Should this be a separate method call?
    pos = obj.convertStagePositionToImageCoords(tp,frontLeft);
    pos = round(pos);
    pos(pos==0)=1;
    obj.previewTilePositions = fliplr(pos);


    % Wipe any data in the down-sampled tile buffer
    obj.downSampledTileBuffer(:)=0;


    success = true;

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
