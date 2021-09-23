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
    slideFrontLeft_X = obj.model.recipe.SYSTEM.slideFrontLeft{1};
    slideFrontLeft_Y = obj.model.recipe.SYSTEM.slideFrontLeft{2};

    % Correct for the tile size, as the coords in the image are top left
    % corner. 
    slideFrontLeft_X = slideFrontLeft_X - (obj.model.recipe.TileStepSize.X/2);
    slideFrontLeft_Y = slideFrontLeft_Y - (obj.model.recipe.TileStepSize.Y/2);

    % TODO -- probably these too should come from settings file
    slideWidth = 25;
    frostedWidth = 18;

    
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

            
    % The slide edge outside of the frosted area
    slideLength = 75;
    x = [slideFrontLeft_X-frostedWidth, slideFrontLeft_X-slideLength, ...
          slideFrontLeft_X-slideLength,slideFrontLeft_X-frostedWidth];

    y = [slideFrontLeft_Y, slideFrontLeft_Y, ...
         slideFrontLeft_Y-slideWidth,slideFrontLeft_Y-slideWidth];     

    pixPos=obj.model.convertStagePositionToImageCoords([x(:),y(:)]);
    obj.plotOverlayHandles.(mfilename)(2) = plot(pixPos(:,1),pixPos(:,2), '--', ...
                'Color', [1,1,1]*0.25, ...
                'Parent', obj.imageAxes);    
            
    hold(obj.imageAxes,'off')

    drawnow

end %overlayStageBoundariesOnImage
