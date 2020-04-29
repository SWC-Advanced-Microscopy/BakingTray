function [stagePos,mmPerPixelDownSampled] = convertImageCoordsToStagePosition(obj, coords)
    % Convert a position in the preview image to a stage position in mm
    %
    % function [stagePos,mmPerPixelDownSampled] = convertImageCoordsToStagePosition(obj, coords)
    %
    % Purpose
    % Convert a pixel coordinate in BT.lastPreviewImageStack to a stage position. 
    %
    %
    % Inputs
    % coords is [x coord, y coord] This is of the image. So x means columns and y means rows.
    % 
    % Outputs
    % stagePos is [x stage pos, y stage pos]
    % xMMPix - number of mm per pixel in X
    % yMMPix - number of mm per pixel in Y
    %
    % Note that the Y axis of the plot is motion of the X stage. This will always be the case.
    % i.e. There is no build scenario where this would be different. 

    verbose=false;

    % Get the pixel size in mm of the downsampled image stack
    mmPerPixelDownSampled = obj.downsampleMicronsPerPixel * 1E-3;

    if isempty(obj.lastPreviewImageStack)
        if verbose
            fprintf('BT.convertImageCoordsToStagePosition can not run: lastPreviewImageStack is empty\n')
        end
        stagePos = [0,0]; %This is the middle of the stage motion
        return
    end

    xAxisCoord = coords(1);
    yAxisCoord = coords(2);


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
    frontRightX = obj.frontLeftWhenPreviewWasTaken.X - size(obj.lastPreviewImageStack,1)*mmPerPixelDownSampled;

    xPosInMM = frontRightX + yAxisCoord*mmPerPixelDownSampled;
    yPosInMM = obj.frontLeftWhenPreviewWasTaken.Y- xAxisCoord*mmPerPixelDownSampled;

    stagePos = [xPosInMM,yPosInMM];

    if verbose
        fprintf('convertImageCoordsToStagePosition -- pixel coords: x=%d y=%d,  stage coords: x=%0.2f y=%0.2f\n', ...
            round(xAxisCoord), round(yAxisCoord), xPosInMM, yPosInMM);
    end

end % convertImageCoordsToStagePosition
