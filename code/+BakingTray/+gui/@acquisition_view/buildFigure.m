function buildFigure(obj)
    % Build the acquisition_view GUI window
    %
    % Called by the constructor

    fprintf('Opening acquisition view\n')
    obj.hFig = BakingTray.gui.newGenericGUIFigureWindow('BakingTray_acquisition');

    % Closing the figure closes the view object
    set(obj.hFig,'CloseRequestFcn', @obj.closeAcqGUI, 'Resize','on')

    % Set the figure window to have a reasonable size
    minFigSize=[800,600];
    LimitFigSize(obj.hFig,'min',minFigSize);
    set(obj.hFig, 'SizeChangedFcn', @obj.updateGUIonResize)
    set(obj.hFig, 'Name', 'BakingTray - Acquisition')

    % Make the status panel
    panelHeight=60;
    obj.statusPanel = BakingTray.gui.newGenericGUIPanel([2, minFigSize(2)-panelHeight, minFigSize(1)-4, panelHeight], obj.hFig);
    if ispc
        textFSize=9;
    else
        textFSize=11;
    end

    obj.statusText = annotation(obj.statusPanel,'textbox', 'Units','Pixels', 'Color', 'w', ...
                                'Position',[0,1,200,panelHeight-4],'EdgeColor','none',...
                                'HorizontalAlignment','left', 'VerticalAlignment','middle',...
                                'FontSize',textFSize);

    %Make the image axes (also see obj.addBlankImageToImageAxes)
    obj.imageAxes = axes('parent', obj.hFig, ...
        'Units','pixels', ...
        'Color', 'k',...
        'Position',[3,2,minFigSize(1)-4,minFigSize(2)-panelHeight-4]);

    % This makes the image origin and the front/left position coincide. 
    set(obj.imageAxes.YAxis,'Direction','reverse')

    %Set up the "compass plot" in the bottom left of the preview axis
    pos=plotboxpos(obj.imageAxes);
    obj.compassAxes = axes('parent', obj.hFig,...
        'Units', 'pixels', 'Color', 'none', ...
        'Position', [pos(1:2),80,80],... %The precise positioning is handled in obj.updateGUIonResize
        'XLim', [-1,1], 'YLim', [-1,1],...
        'XColor','none', 'YColor', 'none');
    hold(obj.compassAxes,'on')
    plot([-0.4,0.64],[0,0],'-r','parent',obj.compassAxes)
    plot([0,0],[-1,1],'-r','parent',obj.compassAxes)
    compassText(1) = text(0.05,0.95,'Left','parent',obj.compassAxes);
    compassText(2) = text(0.05,-0.85,'Right','parent',obj.compassAxes);
    compassText(3) = text(0.65,0.04,'Far','parent',obj.compassAxes);
    compassText(4) = text(-1.08,0.04,'Near','parent',obj.compassAxes);
    set(compassText,'Color','r')
    hold(obj.compassAxes,'off')


    %Set up the bake/stop button
    obj.buttonSettings_BakeStop.bake={'String', 'Bake', ...
                    'Callback', @obj.bake_callback, ...
                    'FontSize', obj.fSize, ...
                    'BackgroundColor', [0.5,1.0,0.5]};


    obj.buttonSettings_BakeStop.stop={'String', 'Stop', ...
                    'Callback', @obj.stop_callback, ...
                    'FontSize', obj.fSize, ...
                    'BackgroundColor', [1,0.5,0.5]};


    obj.buttonSettings_BakeStop.cancelStop={'String', sprintf('<html><p align="center">Cancel<br />Stop</p></html>'), ...
                    'Callback', @obj.stop_callback, ...
                    'FontSize', obj.fSize-1, ...
                    'Callback', @obj.stop_callback, ...
                    'BackgroundColor', [0.95,0.95,0.15]};

    obj.button_BakeStop=uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [205, 12, 60, 32], ...
        'Units','Pixels',...
        'ForegroundColor','k', ...
        'FontWeight', 'bold');


    %Ensure the bake button reflects what is currently happening
    if ~obj.model.acquisitionInProgress
        set(obj.button_BakeStop, obj.buttonSettings_BakeStop.bake{:})
    else obj.model.acquisitionInProgress
        fprintf('Acquisition already in progress when acquisition view starts. Setting Bake button to "Stop".\n')
        set(obj.button_BakeStop, obj.buttonSettings_BakeStop.stop{:})
    end


    %Set up the pause button
    obj.buttonSettings_Pause.disabled={...
                    'ForegroundColor',[1,1,1]*0.5,...
                    'String', 'Pause', ...
                    'BackgroundColor', [0.75,0.75,1.0]};


    obj.buttonSettings_Pause.enabled={...
                    'ForegroundColor','k',...
                    'String', 'Pause', ...
                    'BackgroundColor', [1,0.75,0.25]};


    obj.buttonSettings_Pause.resume={...
                    'ForegroundColor','k',...
                    'String', 'Resume', ...
                    'BackgroundColor', [0.5,1.0,0.5]};

    obj.button_Pause=uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [270, 12, 60, 32], ...
        'Units','Pixels', ...
        'FontSize', obj.fSize, ...
        'FontWeight', 'bold',...
        'Callback', @obj.pause_callback);
    set(obj.button_Pause, obj.buttonSettings_Pause.disabled{:})


    %Pop-ups for selecting which depth and channel to show
    % Create pop-up menu
    obj.depthSelectPopup = uicontrol('Parent', obj.statusPanel, 'Style', 'popup',...
   'Position', [340, 8, 70, 30], 'String', 'depth', 'Callback', @obj.setDepthToView,...
              'Interruptible', 'off');


    %Do not proceed if we can not make a tile pattern
    obj.statusText.String = '** Checking tile pattern **';
    tp=obj.model.recipe.tilePattern;
    if isempty(tp)
        obj.button_BakeStop.Enable='off';
        obj.button_previewScan.Enable='off';
        msg = sprintf(['Your tile pattern likely includes positions that are out of bounds.\n',...
            'Acuisition will fail. Close this window. Fix the problem. Then try again.\n']);
        if isempty(obj.model.scanner)
            msg = sprintf('%sLikely cause: no scanner connected\n',msg);
        end
        warndlg(msg,'');
    end

    % Build a blank image then insert it (nicely formatted) into the axes. 
    % We'll repeat this before acquisition too, so recipe can be altered at any time
    obj.statusText.String = ' ** PLEASE WAIT ** ';
    obj.statusText.Color = 'r';
    obj.model.initialisePreviewImageData(tp);
    obj.addBlankImageToImageAxes;
    drawnow


    % Populate the depth popup
    obj.populateDepthPopup
    obj.setDepthToView; %Ensure that the property is set to a valid depth (it should be anyway)

    obj.channelSelectPopup = uicontrol('Parent', obj.statusPanel, 'Style', 'popup',...
        'Position', [420, 8, 70, 30], 'String', '', 'Callback', @obj.setChannelToView,...
        'Interruptible', 'off');

    % Add the channel names. This is under the control of a listener in case the user makes a 
    % change in ScanImage after the acquisition_view GUI has opened.
    obj.updateChannelsPopup
    obj.setChannelToView % Ensure that the property is set to a valid channel


    % Report the cursor position with a callback function
    set(obj.hFig, 'WindowButtonMotionFcn', @obj.pointerReporter)
    
    % Enable "click to move to position" (double click)
    set(obj.hFig, 'WindowButtonDownFcn', @obj.previewMoveToPosition)


    obj.button_previewScan=uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [705, 31, 85, 25], ...
        'Units','Pixels',...
        'ForegroundColor','k', ...
        'FontWeight', 'bold', ...
        'String', 'Preview Scan', ...
        'BackgroundColor', [1,0.75,0.25], ...
        'Callback', @obj.startPreviewScan);


    obj.button_runAutoThresh=uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [705, 2, 85, 25], ...
        'Units','Pixels',...
        'ForegroundColor','k', ...
        'FontWeight', 'bold', ...
        'String', 'Auto-Thresh', ...
        'BackgroundColor', [1,0.75,0.25], ...
        'Callback', @obj.getThresholdAndOverlayGrid);


    % Add buttons for zooming in and out and drawing the boundary box
    obj.button_zoomIn = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [685 38 15 15], ...
        'Units', 'Pixels', ...
        'String', '+', ...
        'Tag', 'zoomin', ... 
        'ToolTip', 'Zoom in', ...
        'Callback', @obj.imageZoomHandler);

    obj.button_zoomOut = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [685 2 15 15], ...
        'Units', 'Pixels', ...
        'String', '-', ...
        'Tag', 'zoomout', ... 
        'ToolTip', 'Zoom out', ...
        'Callback', @obj.imageZoomHandler);


    obj.button_zoomNative = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [685 20 15 15], ...
        'Units', 'Pixels', ...
        'String', '0', ...
        'Tag', 'zerozoom', ...
        'ToolTip', 'Reset zoom',... 
        'Callback', @obj.imageZoomHandler);


    obj.button_drawBox = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [630 32 50 20], ...
        'Units', 'Pixels', ...
        'String', 'ROI', ...
        'ToolTip', 'Select area to image', ...
        'Callback', @obj.areaSelector);


    obj.button_showSlide = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Position', [630 2 50 20], ...
        'Units', 'Pixels', ...
        'String', 'Slide', ...
        'ToolTip', 'Zoom out and show slide', ...
        'Callback', @obj.showSlide);

    % Add checkboxes for toggling disabling the laser and showing the slide
    obj.checkBoxLaserOff = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Units', 'Pixels', ...
        'String', 'Laser off', ...
        'Position', [515, 32, 70, 17], ...
        'Style','check', ... 
        'ToolTip', 'Turn off laser when acquisition finishes', ...
        'ForegroundColor', 'w', ...
        'BackgroundColor', [1,1,1]*0.075, ...
        'Value', ~obj.model.leaveLaserOn, ...
        'Callback', @obj.updateLeaveLaserOn);


    obj.checkBoxShowSlide = uicontrol(...
        'Parent', obj.statusPanel, ...
        'Units', 'Pixels', ...
        'String', 'Show slide', ...
        'Position', [515, 5, 110, 17], ...
        'Style','check', ... 
        'ToolTip', 'Show slide frosted area', ...
        'ForegroundColor', 'w', ...
        'BackgroundColor', [1,1,1]*0.075, ...
        'Value', 0, ...
        'Callback', @obj.showSlideCheckBoxCallback);

    % Ensure any another recipe-related things are up to date
    obj.recipeListener
    
    
    obj.listeners{end+1}=addlistener(obj.parentView.view_prepare, 'lastXpos', 'PostSet', @obj.updateStagePosOnImage);
    obj.listeners{end+1}=addlistener(obj.parentView.view_prepare, 'lastYpos', 'PostSet', @obj.updateStagePosOnImage);
    

    % By default we show the slide. 
    obj.showSlide
end %close buildFigure
