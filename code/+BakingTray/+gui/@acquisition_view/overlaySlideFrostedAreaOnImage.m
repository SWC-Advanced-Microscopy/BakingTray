function overlaySlideFrostedAreaOnImage(obj)
    % Overlay transparent rectangle indicating the frosted area of the slide
    %
    %
    % Purpose
    % Display to the user the frosted part of the slide to help with orienting themselves. 
    %
    % Inputs
    % none
    %
    %
    %
    % See also:
    % obj.overlayTileGridOnImage
    % obj.overlayBoundingBoxesOnImage
    % obj.overlayPointsOnImage
    % obj.removeOverlays


    % Set up
    hold(obj.imageAxes,'on')
    obj.removeOverlays(mfilename)

    % All measurements in mm 
    slideFrontLeft_X = 15;  % TODO: must come from settings file
    slideFrontLeft_Y = 12.5; % TODO: must come from settings file

    % TODO -- probably these too should come from settings file
    slideWidth = 25;
    frostedWidth = 20;


    x = [slideFrontLeft_X, slideFrontLeft_X-frostedWidth, slideFrontLeft_X-frostedWidth, slideFrontLeft_X, slideFrontLeft_X];
    y = [slideFrontLeft_Y, slideFrontLeft_Y, slideFrontLeft_Y-slideWidth, slideFrontLeft_Y-slideWidth, slideFrontLeft_Y];


    pixPos=obj.model.convertStagePositionToImageCoords([x(:),y(:)]);



    %obj.plotOverlayHandles.(mfilename) = plot(pixPos(:,1),pixPos(:,2),'-g','Parent',obj.imageAxes,'LineWidth',4);
    obj.plotOverlayHandles.(mfilename) = patch(pixPos(:,1),pixPos(:,2),0, ...
                'FaceColor', 'w', ...
                'EdgeColor', 'w', ...
                'FaceAlpha', 0.1, ...
                'EdgeAlpha', 0.25, ...
                'Parent', obj.imageAxes);

    hold(obj.imageAxes,'off')

    drawnow

end %overlayStageBoundariesOnImage
