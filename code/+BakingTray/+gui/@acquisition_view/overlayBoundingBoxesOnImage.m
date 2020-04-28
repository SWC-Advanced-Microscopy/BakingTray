function H=overlayBoundingBoxesOnImage(obj,boundingBoxes)
    % Overlay points at defined x and y locations on preview image. This function used for testing right now. 
    % TESTING


    hold(obj.imageAxes,'on')

    for ii=1:length(boundingBoxes)
        b=boundingBoxes{ii};
        x=[b(1), b(1)+b(3), b(1)+b(3), b(1), b(1)];
        y=[b(2), b(2), b(2)+b(4), b(2)+b(4), b(2)];
        H(ii)=plot(x,y,'--y','LineWidth',2,'Parent',obj.imageAxes);
    end


    hold(obj.imageAxes,'off')
end %overlayPointsOnImage
