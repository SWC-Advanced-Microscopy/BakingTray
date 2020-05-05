function [imageCoords,mmPerPixelDownSampled] = convertStagePositionToImageCoords(obj, coords)
    % Convert a stage position to a pixel position in the preview image space
    %
    % function [imageCoords,mmPerPixelDownSampled] = convertStagePositionToImageCoords(obj, coords)
    %
    % Purpose
    % Convert a stage position to a pixel position in the preview image space
    %
    %
    % Inputs
    % coords - [x coord, y coord] This is a position in mm of the stages. Coords may
    %          have multiple rows, in which case the function converts each row to 
    %          image coordinates.
    %
    %
    % Outputs
    % imageCoords is [image columns, image rows]
    %
    % Also see: convertImageCoordsToStagePosition

    % Note that the Y axis of the plot is motion of the X stage. This will always be the case.
    % i.e. There is no build scenario where this would be different. 

    % Get the pixel size in mm of the downsampled image stack
    mmPerPixelDownSampled = obj.downsampleMicronsPerPixel * 1E-3;

    if isempty(obj.lastPreviewImageStack)
        fprintf('BT.convertStagePositionToImageCoords can not run: lastPreviewImageStack is empty. Returning [0,0]\n')
        imageCoords = [0,0]; %This is the middle of the stage motion
        return
    end

    % The image axes origin is the front/right position of the stage. W
    frontRightX = obj.frontLeftWhenPreviewWasTaken.X - size(obj.lastPreviewImageStack,1)*mmPerPixelDownSampled;
    frontLeftY =  obj.frontLeftWhenPreviewWasTaken.Y;

    % First we subtract the offset (front/left position) of the image
    coords(:,1) = coords(:,1)-frontRightX;
    coords(:,2) = frontLeftY -  coords(:,2);


    % Second we convert from mm to pixels
    coords = coords / mmPerPixelDownSampled;

    % Flip because stage and image X/Y are different
    imageCoords = fliplr(coords);

end % convertImageCoordsToStagePosition
