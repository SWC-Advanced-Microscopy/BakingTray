function zoomOutToShowSlide(obj,src,~)

    % Zoom out sufficiently to show the whole frosted area

    % All measurements in mm 
    slideFrontLeft_X = obj.model.recipe.SYSTEM.slideFrontLeft{1};
    slideFrontLeft_Y = obj.model.recipe.SYSTEM.slideFrontLeft{2};
    
    % TODO -- probably these too should come from settings file
    slideWidth = 25;
    frostedWidth = 18*2; % Because people can put brains further along the slide
    
    border=4;
    
    x = [slideFrontLeft_X+border, slideFrontLeft_X-frostedWidth-border];
    y = [slideFrontLeft_Y+border, slideFrontLeft_Y-slideWidth-border];
    
    limsInPixelPos=obj.model.convertStagePositionToImageCoords([x(:),y(:)]);
    
    obj.imageAxes.YLim = limsInPixelPos(:,2);
    obj.imageAxes.XLim = limsInPixelPos(:,1);
     
end
