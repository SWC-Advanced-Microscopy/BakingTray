function H=overlayBoundingBoxesOnImage(obj,boundingBoxes,removePrevious)
    % Overlay one or more bounding boxes onto the preview image 
    %
    % Purpose
    % Overlay one or more bounding boxes onto the preview image. By default
    % removes previous bounding boxes before overlaying new ones. 
    %
    %
    % Inputs
    % boundingBoxes - a cell array of multiple bounding boxes or a single 
    %               vector of length 4 defining one bounding box. The box is 
    %               defined as: [x top/left, y top/left, width, height]
    % 
    % removePrevious - optional. true by default. If false, previous bounding 
    %                  boxes are not removed.
    %
    %
    % Example:
    % Plot a 100 x 200 bounding box in the top left corner (the front/left position)
    % >> hBTview.view_acquire.overlayBoundingBoxesOnImage([1,1,100,200])
    %
    % Now add a second box
    % >> hBTview.view_acquire.overlayBoundingBoxesOnImage([30,100,100,100],false)
    %
    %
    % Also see:
    % obj.overlayTileGridOnImage
    % obj.overlayPointsOnImage
    % obj.removeOverlays


    % Convert to cell array if it's a vector
    if ~iscell(boundingBoxes) && length(boundingBoxes)==4
        boundingBoxes = {boundingBoxes};
    end

    fieldName = 'boundingBoxes'; % The field where we will store the handles

    if nargin<3
        removePrevious=true;
    end

    if removePrevious
        obj.removeOverlays(fieldName)
    end



    hold(obj.imageAxes,'on')

    for ii=1:length(boundingBoxes)
        b=boundingBoxes{ii};
        x=[b(1), b(1)+b(3), b(1)+b(3), b(1), b(1)];
        y=[b(2), b(2), b(2)+b(4), b(2)+b(4), b(2)];
        H(ii)=plot(x,y,'--y','LineWidth',2,'Parent',obj.imageAxes);
    end

    hold(obj.imageAxes,'off')


    % Add handles to the structure obj.plotOverlayHandles
    if ~isfield(obj.plotOverlayHandles, fieldName)
        obj.plotOverlayHandles.(fieldName) = [];
    end

    obj.plotOverlayHandles.(fieldName) = [obj.plotOverlayHandles.(fieldName), H];



end %overlayBoundingBoxesOnImage
