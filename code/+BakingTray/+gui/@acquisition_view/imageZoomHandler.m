function imageZoomHandler(obj,src,~)
    % This callback function is run when the user presses the zoom out, in, or zero zoom
    % buttons in the control bar at the top of the GUI.

    zoomProp=0.15; % How much to zoom in and out each time the button is pressed

    switch src.Tag
    case 'zoomin'
        % Determine first if zooming in is possible
        YLim =[obj.imageAxes.YLim(1) + size(obj.model.lastPreviewImageStack,2)*zoomProp, ... 
            obj.imageAxes.YLim(2) - size(obj.model.lastPreviewImageStack,2)*zoomProp];

        XLim = [obj.imageAxes.XLim(1) + size(obj.model.lastPreviewImageStack,1)*zoomProp, ...
            obj.imageAxes.XLim(2) - size(obj.model.lastPreviewImageStack,1)*zoomProp];

        if diff(YLim)<1 || diff(XLim)<1
            % Then we've tried to zoom in too far, disable the zoom in button
            obj.button_zoomIn.Enable='off';
            return
        end
        obj.imageAxes.YLim(1) = obj.imageAxes.YLim(1) + size(obj.model.lastPreviewImageStack,2)*zoomProp;
        obj.imageAxes.YLim(2) = obj.imageAxes.YLim(2) - size(obj.model.lastPreviewImageStack,2)*zoomProp;
        obj.imageAxes.XLim(1) = obj.imageAxes.XLim(1) + size(obj.model.lastPreviewImageStack,1)*zoomProp;
        obj.imageAxes.XLim(2) = obj.imageAxes.XLim(2) - size(obj.model.lastPreviewImageStack,1)*zoomProp;
    case 'zoomout'
        obj.button_zoomIn.Enable='on'; %In case it was previously disabled
        obj.imageAxes.YLim(1) = obj.imageAxes.YLim(1) - size(obj.model.lastPreviewImageStack,2)*zoomProp;
        obj.imageAxes.YLim(2) = obj.imageAxes.YLim(2) + size(obj.model.lastPreviewImageStack,2)*zoomProp;
        obj.imageAxes.XLim(1) = obj.imageAxes.XLim(1) - size(obj.model.lastPreviewImageStack,1)*zoomProp;
        obj.imageAxes.XLim(2) = obj.imageAxes.XLim(2) + size(obj.model.lastPreviewImageStack,1)*zoomProp;
    case 'zerozoom'
        obj.button_zoomIn.Enable='on'; %In case it was previously disabled
        obj.imageAxes.YLim = [0,size(obj.model.lastPreviewImageStack,2)];
        obj.imageAxes.XLim = [0,size(obj.model.lastPreviewImageStack,1)];
    otherwise 
        fprintf('bakingtray.gui.acquisition_view.imageZoomHandler encounters unknown source tag: "%s"\n',src.Tag)
    end

end