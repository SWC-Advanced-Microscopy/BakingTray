function [stagePos,mmPerPixelDownSampled] = convertImageCoordsToStagePosition(obj, coords)
    % Convert a position in the preview image to a stage position in mm
    %
    % Inputs
    % coords is [x coord, y coord]
    % 
    % Outputs
    % stagePos is [x stage pos, y stage pos]
    % xMMPix - number of mm per pixel in X
    % yMMPix - number of mm per pixel in Y
    %
    % Note that the Y axis of the plot is motion of the X stage.

    xAxisCoord = coords(1);
    yAxisCoord = coords(2);

    % Determine the size of the image in mm
    mmPerPixelDownSampled = obj.model.downsampleMicronsPerPixel * 1E-3;

    % How the figure is set up:
    % * The Y axis of the image (rows) corresponds to motion of the X stage. 
    %   X stage values go negative as we move up the axis (where axis values become more postive)
    % 
    % * The X axis of the image (columns) corresponds to motion of the Y stage
    %   Both Y stage values and X axis values become more positive as we move to the right.
    %
    % * The front/left position is at the top left of the figure

    % Note that the figure x axis is the y stage axis, hence the confusing mixing of x and y below

    % Get the X stage value for y=0 (right most position) and we'll reference off that
    frontRightX = obj.frontLeftWhenPreviewWasTaken.X - size(obj.previewImageData,2)*mmPerPixelDownSampled;

    xPosInMM = frontRightX + yAxisCoord*mmPerPixelDownSampled;
    yPosInMM = obj.frontLeftWhenPreviewWasTaken.Y- xAxisCoord*mmPerPixelDownSampled;

    stagePos = [xPosInMM,yPosInMM];
end % convertImageCoordsToStagePosition