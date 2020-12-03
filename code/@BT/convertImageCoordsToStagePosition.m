function [stagePos,mmPerPixelDownSampled] = convertImageCoordsToStagePosition(obj, coords, frontLeftStageCoord)
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
    %     % TODO -- doc fully as frontLeftStageCoord is new argument
    % 
    % Outputs
    % stagePos is [x stage pos, y stage pos]
    % xMMPix - number of mm per pixel in X
    % yMMPix - number of mm per pixel in Y
    %
    %
    % Note that the Y axis of the plot is motion of the X stage. This will always be the case.
    % i.e. There is no build scenario where this would be different. 

    verbose=false;

    if nargin<3
        frontLeftStageCoord.X = obj.frontLeftWhenPreviewWasTaken.X;
        frontLeftStageCoord.Y = obj.frontLeftWhenPreviewWasTaken.Y;
    end

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
    %   X stage values go more negative as we move up the rows (x origin of image at the top)
    % 
    % * The X axis of the image (columns) corresponds to motion of the Y stage
    %
    % * The front/left position is at the top left of the figure

    % Note that the figure x axis is the y stage axis, hence the confusing mixing of x and y below

    % Since the image axes origin corresponds to the front/left position of the stage we simply:
    xPosInMM = frontLeftStageCoord.X - yAxisCoord*mmPerPixelDownSampled;
    yPosInMM = frontLeftStageCoord.Y - xAxisCoord*mmPerPixelDownSampled;

    stagePos = [xPosInMM,yPosInMM];

    if verbose
        fprintf('convertImageCoordsToStagePosition -- pixel coords: x=%d y=%d,  stage coords: x=%0.2f y=%0.2f\n', ...
            round(xAxisCoord), round(yAxisCoord), xPosInMM, yPosInMM);
    end

end % convertImageCoordsToStagePosition
