function buildWindow(obj)
    % Build the window for the prepare GUI.
    %
    % i.e. this builds the "view"
    %
    % Rob Campbell SWC

    obj.hFig = BakingTray.gui.newGenericGUIFigureWindow('BakingTray_prepare');

    % Closing the figure closes the prepare_view object
    set(obj.hFig,'CloseRequestFcn', @obj.closeComponentView);

    %Resize the figure window
    pos=get(obj.hFig, 'Position');
    pos(3:4)=[279,453];
    set(obj.hFig, ...
        'Position',pos, ...
        'Name', 'BakingTray - Prepare Sample')
    obj.positionNextToBakingTrayView;

    %Set up default jog sizes for x/y and z
    %These are kept up to date with the updateJogProperies callback function
    obj.resetStepSizesToDefaults


    %Load icons
    iconPath = fileparts(which('BakingTray.gui.prepare_view'));
    iconPath = fullfile(iconPath,'icons');
    doubleArrow = imread(fullfile(iconPath,'left_double_arrow.tiff'));
    singleArrow = imread(fullfile(iconPath,'left_single_arrow.tiff'));
    doubleArrow = single(doubleArrow)/(2^8-1);
    singleArrow = single(singleArrow)/(2^8-1);
    doubleArrow = abs(doubleArrow-1);
    singleArrow = abs(singleArrow-1);


    %Build "move" buttons in a panel
    obj.move_panel = BakingTray.gui.newGenericGUIPanel([5,188,270,260], obj.hFig);

    % Buttons to raise and lower the stage
    obj.lowerZstage_button=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'lowerZstage', ...
        'Position', [7,230,100,25], ...
        'String', 'Lower Z stage', ...
        'Callback', @(~,~) obj.model.lowerZstage, ...
        'Enable', 'off');

    obj.raiseSample_button=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'raiseSample', ...
        'Position', [110,230,100,25], ...
        'String', 'Raise sample', ...
        'Callback', @(~,~) obj.model.raiseSample, ...
        'Enable', 'off');


    buttonSize=[30,30];
    stepEditSize=[30,25];

    % Buttons for X
    xButtonH=105; %positions X buttons along the height on the panel
    firstButtonX =7; %Pixel row position of first button
    obj.largeStep.left=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'large||left', ...
        'Position', [firstButtonX xButtonH buttonSize], ...
        'CData', doubleArrow);

    obj.smallStep.left=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'small||left', ...
        'Position', [firstButtonX+35 xButtonH buttonSize], ...
        'CData', singleArrow);

    obj.smallStep.right=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'small||right', ...
        'Position', [firstButtonX+120 xButtonH buttonSize], ...
        'CData', fliplr(singleArrow));

    obj.largeStep.right=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'large||right', ...
        'Position', [firstButtonX+155 xButtonH buttonSize], ...
        'CData', fliplr(doubleArrow));

    % Buttons for Y
    yButtonR=85; %positions Y buttons along this pixel row
    firstButtonH=15; %Pixel of first button
    obj.largeStep.away=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'large||away', ...
        'Position', [yButtonR firstButtonH+170 buttonSize], ...
        'CData', flipud(rot90(doubleArrow)));

    obj.smallStep.away=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'small||away', ...
        'Position', [yButtonR firstButtonH+135 buttonSize], ...
        'CData', flipud(rot90(singleArrow)));

    obj.smallStep.towards=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'small||towards', ...
        'Position', [yButtonR firstButtonH+35 buttonSize], ...
        'CData', rot90(singleArrow));

    obj.largeStep.towards=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'large||towards', ...
        'Position', [yButtonR firstButtonH buttonSize], ...
        'CData', rot90(doubleArrow));


    %Step sizes for text boxes
    obj.editBox.smallStepSizeXY=uicontrol('Parent', obj.move_panel, ...
        'Position', [yButtonR firstButtonH+73 stepEditSize], ...
        'Style','edit', ...
        'Tag','XY||small', ...
        'TooltipString','Size of small X/Y jog motions in mm', ...
        'String',obj.xyJogSizes.small, ...
        'Callback',@obj.updateJogProperties);

    obj.editBox.largeStepSizeXY=uicontrol('Parent', obj.move_panel, ...
        'Position', [yButtonR firstButtonH+101 stepEditSize], ...
        'Style','edit', ...
        'Tag','XY||large', ...
        'TooltipString','Size of large X/Y jog motions in mm', ...
        'String',obj.xyJogSizes.large, ...
        'Callback',@obj.updateJogProperties);


    % Buttons for Z
    zButtonR=225; %positions Z buttons along this pixel row
    obj.largeStep.up=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'large||up', ...
        'Position', [zButtonR firstButtonH+170 buttonSize], ...
        'CData', flipud(rot90(doubleArrow)));

    obj.smallStep.up=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'small||up', ...
        'Position', [zButtonR firstButtonH+135 buttonSize], ...
        'CData', flipud(rot90(singleArrow)));

    obj.smallStep.down=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'small||down', ...
        'Position', [zButtonR firstButtonH+35 buttonSize], ...
        'CData', rot90(singleArrow));

    obj.largeStep.down=uicontrol('Parent', obj.move_panel, ...
        'Tag', 'large||down', ...
        'Position', [zButtonR firstButtonH buttonSize], ...
        'CData', rot90(doubleArrow));


    obj.editBox.smallStepSizeZ=uicontrol('Parent', obj.move_panel, ...
        'Position', [zButtonR firstButtonH+73 stepEditSize], ...
        'Style','edit', ...
        'Tag','Z||small', ...
        'TooltipString','Size of small Z jog motions in mm', ...
        'String',obj.zJogSizes.small, ...
        'Callback',@obj.updateJogProperties);

    obj.editBox.largeStepSizeZ=uicontrol('Parent', obj.move_panel, ...
        'Position', [zButtonR firstButtonH+101 stepEditSize], ...
        'Style','edit', ...
        'Tag','Z||large', ...
        'TooltipString','Size of large Z jog motions in mm', ...
        'String',obj.zJogSizes.large, ...
        'Callback',@obj.updateJogProperties);


    %Add text entry boxes for absolute moves
    obj.absMove_panel = BakingTray.gui.newGenericGUIPanel([130,14,80,83], obj.move_panel);

    buttonRowPos=25;
    absPosSize=[45,20];
    commonEditBoxProps={'Parent', obj.absMove_panel, 'Style','edit'};

    obj.editBox.xPos=uicontrol(commonEditBoxProps{:}, ...
        'Position', [buttonRowPos 55 absPosSize], ...
        'TooltipString','Current X position and absolute move command', ...
        'String', sprintf('%0.3f',obj.model.getXpos),...
        'Tag','xAxis',...
        'Callback', @obj.executeAbsoluteMotion);
    obj.editBox.yPos=uicontrol(commonEditBoxProps{:}, ...
        'Position', [buttonRowPos 30 absPosSize], ...
        'TooltipString','Current Y position and absolute move command', ...
        'String', sprintf('%0.3f',obj.model.getYpos),...
        'Tag','yAxis',...
        'Callback', @obj.executeAbsoluteMotion);
    obj.editBox.zPos=uicontrol(commonEditBoxProps{:}, ...
        'Position', [buttonRowPos 5 absPosSize], ...
        'TooltipString','Current Z position and absolute move command', ...
        'String', sprintf('%0.3f',obj.model.getZpos),...
        'Tag','zAxis',...
        'Callback', @obj.executeAbsoluteMotion);

    commonEditBoxProps={obj.absMove_panel, 'textbox', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'Center', 'Units','Pixels', ...
        'Color', 'w','FontSize', obj.fSize, 'FitBoxToText','off'};
    labelSize=[15,20];
    obj.labels.xAbs=annotation(commonEditBoxProps{:}, ...
        'Position', [5,55,labelSize], ...
        'String', 'X');
    obj.labels.yAbs=annotation(commonEditBoxProps{:}, ...
        'Position', [5,30,labelSize], ...
        'String', 'Y');
    obj.labels.zAbs=annotation(commonEditBoxProps{:}, ...
        'Position', [5,5,labelSize], ...
        'String', 'Z');


    %Stop motion button
    obj.stopMotion_button=uicontrol('Parent', obj.move_panel, ...
        'Position', [7,7,72,45], ...
        'String','STOP', ...
        'FontSize',obj.fSize+2, ...
        'FontWeight','Bold', ...
        'ForegroundColor','w', ...
        'BackgroundColor','r', ...
        'Callback',@obj.stopAllAxes);
    if ~obj.suppressToolTips
        obj.stopMotion_button.TooltipString='Stop all axes';
    end


    % Lock Z-axes axes button. If a cutting position is set (it is not NaN) then
    % this is automatically locked so the user can not accidently move the Z
    % jack stage. When locked the buttons for Z are greyed out and the keyboard
    % combos do not run.
    obj.lockZ_checkbox = uicontrol('Parent',obj.move_panel, ...
        'Style','Checkbox', ...
        'Position', [1,70,75,19], ...
        'FontSize', obj.fSize, ...
        'Value', 0, ...
        'ForegroundColor','w', ...
        'BackgroundColor','k', ...
        'String', 'Lock Z',...
        'ToolTip', sprintf(['When checked, the sample Z axis can not be moved.\nThe Z Lock is applied automatically ', ...
                'after the first slice is cut during sample setup.\n']), ...
        'Callback',@obj.lockZ_callback);


    % ----------------------------
    % cutting and start position buttons
    obj.plan_panel = BakingTray.gui.newGenericGUIPanel([5,97,270,89], obj.hFig);
    commonButtonProps={'Parent',obj.plan_panel,'FontSize',obj.fSize};
    obj.setCuttingPos_button=uicontrol(commonButtonProps{:}, ...
        'Position',[3,59,130,25], ...
        'String','Set blade position', ...
        'Callback', @obj.setCuttingPos_callback );


    % Text edit boxes for the cutting start point
    commonXYtextProps={'Color','w', 'FontSize', obj.fSize, 'Units','Pixels'};
    obj.labels.cut_X = annotation(obj.plan_panel, 'textbox', commonXYtextProps{:}, ...
        'Position', [135, 65, 10, 18], 'String', 'X=');

    obj.labels.cutSize_X = annotation(obj.plan_panel, 'textbox', commonXYtextProps{:}, ...
        'Position', [60, 40, 100, 18], 'String', 'Cut Size (mm)');


    commonXYEditBoxProps={'Parent', obj.plan_panel, 'Style','edit'};

    obj.editBox.cut_X = uicontrol(commonXYEditBoxProps{:}, ...
        'ToolTipString', 'X cutting position', ...
        'Callback', @obj.updateRecipeCutPointOnEditBoxChange, ...
        'Position', [159,64,39,17], 'Tag', 'CuttingStartPoint||X');


    obj.editBox.cutSize_X = uicontrol(commonXYEditBoxProps{:}, ...
        'ToolTipString', 'Cut size (agar block width)', ...
        'Callback', @obj.updateRecipeCutPointOnEditBoxChange, ...
        'Position', [159,39,39,17], 'Tag', 'mosaic||cutSize');


    obj.updateCuttingConfigurationText


    % ----------------------------
    %The slice panel contains all things cutting related.
    %The trim panel within it is for the buttons users press to take one or more slices
    obj.slice_panel = BakingTray.gui.newGenericGUIPanel([5,5,270,90], obj.hFig);
    sliceButtonCommon={'ForegroundColor','k','FontWeight', 'bold', ...
            'FontSize', obj.fSize};

    obj.autoTrim_button=uicontrol(sliceButtonCommon{:}, ...
        'Parent', obj.slice_panel, ...
        'Position', [169, 60, 90, 20], ...
        'String', 'Auto-Trim', ...
        'Callback', @obj.autoTrim);

    obj.trim_panel = BakingTray.gui.newGenericGUIPanel([10,35,150,48], obj.slice_panel);

    set(obj.trim_panel,'BorderType','line', ...
        'BackgroundColor',[1,1,1]*0.11);

    obj.takeSlice_button=uicontrol(sliceButtonCommon{:}, ...
        'Parent', obj.trim_panel, ...
        'Position', [10, 2, 90, 20], ...
        'String', obj.takeSlice_buttonString, ...
        'Callback', @obj.takeOneSlice);

    obj.takeNSlices_button=uicontrol(sliceButtonCommon{:}, ...
        'Parent', obj.trim_panel, ...
        'Position', [10, 25, 90, 20], ...
        'String', 'Slice N times', ...
        'Callback', @obj.takeNslices);

    obj.editBox.takeNslices = uicontrol('Parent', obj.trim_panel, ...
        'Position', [110, 25 25,20], ...
        'Style','edit', ...
        'TooltipString','Number of slices to change in succession', ...
        'Callback', @obj.checkNumSlices,...
        'String',obj.lastNslicesValue);



    % Slice speed and thickness
    % These influence only what is done during preparation. The main view class that spawns the prepare
    % window sets each value to green if it matches that in the recipe.

    %If the user has previously sliced, build GUI with these values instead
    if ~isempty(obj.model.recipe.lastSliceThickness)
        obj.lastSliceThickness=obj.model.recipe.lastSliceThickness;
    end
    if ~isempty(obj.model.recipe.lastCuttingSpeed)
        obj.lastCuttingSpeed=obj.model.recipe.lastCuttingSpeed;
    end

    obj.labels.sliceThickness=annotation(obj.slice_panel,'textbox', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'Right', 'Units','Pixels', ...
        'Color', 'w','FontSize', obj.fSize, 'FitBoxToText','off', ...
        'Position', [0,10,95,20], ...
        'VerticalAlignment', 'middle',...
        'String', 'Thickness (mm)');

    obj.editBox.sliceThickness=uicontrol('Parent', obj.slice_panel, ...
         'Style','edit', 'Position', [97, 10, 38,20], ...
        'TooltipString',sprintf('How thick to cut the next slice.\nDuring acquisition, the slice thickness is defined by the recipe.'), ...
        'String',obj.lastSliceThickness,...
        'Callback', @obj.checkSliceThicknessEditBoxValue);
    %Trigger the callback to color the label text as needed
    obj.checkSliceThicknessEditBoxValue


    obj.labels.cuttingSpeed=annotation(obj.slice_panel,'textbox', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'Right', 'Units','Pixels', ...
        'Color', 'w','FontSize', obj.fSize, 'FitBoxToText','off', ...
        'Position', [137,10,87,20], ...
        'VerticalAlignment', 'middle',...
        'String', 'Speed (mm/s)');
    obj.editBox.cuttingSpeed=uicontrol('Parent', obj.slice_panel, ...
         'Style','edit', 'Position', [225, 10, 38,20], ...
        'TooltipString',sprintf('How fast to cut the next slice (mm/s).\nDuring acquisition, the slice speed is defined by the recipe.'), ...
        'String',obj.lastCuttingSpeed,...
        'Callback', @obj.checkCuttingSpeedEditBoxValue);
    %Trigger the callback to color the label text as needed
    obj.checkCuttingSpeedEditBoxValue;





    % Add listeners on the three stage axes in order to update the stage position should the stage move.
    % So whenever the axis position is read, that axis will have its position updated on screen. If an
    % axis is moved and the position is not read back, the screen won't update either,
    obj.listeners{end+1}=addlistener(obj.model.xAxis.attachedStage, 'currentPosition', 'PostSet', @obj.updateXaxisEditBox);
    obj.listeners{end+1}=addlistener(obj.model.yAxis.attachedStage, 'currentPosition', 'PostSet', @obj.updateYaxisEditBox);
    obj.listeners{end+1}=addlistener(obj.model.zAxis.attachedStage, 'currentPosition', 'PostSet', @obj.updateZaxisEditBox);

    % Listener to update the front/left and cutting positions should they be altered at the command in the recipe object
    obj.listeners{end+1}=addlistener(obj.model.recipe, 'FrontLeft', 'PostSet', @obj.updateCuttingConfigurationText);
    obj.listeners{end+1}=addlistener(obj.model.recipe, 'CuttingStartPoint', 'PostSet', @obj.updateCuttingConfigurationText);

    % Listener to update GUI during slicing
    obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.updateElementsDuringSlicing);

    % GUI is rendered inactive during acquisition
    obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.updateGUIduringAcq);

    %Call hMover_KeyPress on keypress events
    set(obj.hFig,'KeyPressFcn', {@hMover_KeyPress,obj}); %see private code dir for this class


    set(obj.largeStep.away, 'Callback', @obj.executeJogMotion);
    set(obj.largeStep.towards,'Callback',@obj.executeJogMotion);
    set(obj.largeStep.right,'Callback',@obj.executeJogMotion);
    set(obj.largeStep.left,'Callback',@obj.executeJogMotion);
    set(obj.largeStep.up,'Callback',@obj.executeJogMotion);
    set(obj.largeStep.down,'Callback',@obj.executeJogMotion);

    set(obj.smallStep.away,'Callback',@obj.executeJogMotion);
    set(obj.smallStep.towards,'Callback',@obj.executeJogMotion);
    set(obj.smallStep.right,'Callback',@obj.executeJogMotion);
    set(obj.smallStep.left,'Callback',@obj.executeJogMotion);
    set(obj.smallStep.up,'Callback',@obj.executeJogMotion);
    set(obj.smallStep.down,'Callback',@obj.executeJogMotion);


    if obj.suppressToolTips
        %just wipe them all
        f=fields(obj.editBox);
        for ii=1:length(f)
            set(obj.editBox.(f{ii}),'TooltipString','')
        end
    end

end
