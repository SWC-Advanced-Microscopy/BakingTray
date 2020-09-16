classdef prepare_view < BakingTray.gui.child_view
    % bakingtray.gui.prepare_view handles motion commands, cutting, setting of start position
    %
    % obj=bakingtray.gui.prepare_view(hBT,hBTview)
    %

    properties

        %Buttons
        largeStep=struct
        smallStep=struct
        stopMotion_button
        takeSlice_button
        takeNSlices_button

        setCuttingPos_button
        setFrontLeft_button
        setVentralMidline_button

        moveToSample_button
    end

    properties (Hidden)
        hBTview  % Handle to the main view class that spawns this GUI
        % The following properties store GUI panel handles
        move_panel
        slice_panel
        absMove_panel
        plan_panel
        sliceNtimes_panel

        suppressToolTips=false
        labels=struct

        jogSizeCoarseOrFine='fine' %can also be "coarse" TODO: add a radio button and callback to switch between coarse and fine 
        lastSliceThickness=0.1
        lastCuttingSpeed=0.5

        %Timer-related properties. These are involved in keeping the GUI up to date
        prepareViewUpdateTimer
        prepareViewUpdateInterval=1 % Update select GUI elements every this many seconds (e.g. axis position)
    end

    properties (Hidden,Access=protected)
        editBox=struct %The edit boxes all go in here
        xyJogSizes=struct
        zJogSizes=struct

        takeSlice_buttonString='Slice once'
        %The following two are used to correct invalid entries

        lastNslicesValue=1

        %Ready text color: the color of a text element when it's at the correct value to proceed
        readyTextColor=[0.25,1,0.25]

        lastXpos=0
        lastYpos=0
        lastZpos=0
    end

    methods

        function obj=prepare_view(hBT,hBTview)
            obj = obj@BakingTray.gui.child_view;

            if nargin>1
                %If the BT view created this panel, it will provide this argument
                obj.hBTview=hBTview;
            end

            %Do not proceed if any components are missing
            msg = hBT.checkForPrepareComponentsThatAreNotConnected;
            if ~isempty(msg)
                fprintf('Not starting BakingTray.gui.prepare_view:\n%s\n',msg)
                obj.delete
            end

            %Keep a copy of the BT model
            obj.model = hBT;

            obj.hFig = BakingTray.gui.newGenericGUIFigureWindow('BakingTray_prepare');

            % Closing the figure closes the prepare_view object
            set(obj.hFig,'CloseRequestFcn', @obj.closeComponentView);

            %Resize the figure window
            pos=get(obj.hFig, 'Position');
            pos(3:4)=[279,423];
            set(obj.hFig, ...
                'Position',pos, ... 
                'Name', 'BakingTray - Prepare Sample')
            obj.positionNextToBakingTrayView;

            %Set up default jog sizes for x/y and z 
            %These are kept up to date with the updateJogProperies callback function
            obj.xyJogSizes.fine.small=0.1;
            obj.xyJogSizes.fine.large=0.5;
            obj.zJogSizes.coarse.small=0.5;
            obj.zJogSizes.coarse.large=2;

            obj.zJogSizes.fine.small=0.05;
            obj.zJogSizes.fine.large=0.5;
            obj.zJogSizes.coarse.small=0.5;
            obj.zJogSizes.coarse.large=2;

            %Load icons
            iconPath = fileparts(which('BakingTray.gui.prepare_view'));
            iconPath = fullfile(iconPath,'icons');
            doubleArrow = imread(fullfile(iconPath,'left_double_arrow.tiff'));
            singleArrow = imread(fullfile(iconPath,'left_single_arrow.tiff'));
            doubleArrow = single(doubleArrow)/(2^8-1);
            singleArrow = single(singleArrow)/(2^8-1);
            doubleArrow = abs(doubleArrow-1);
            singleArrow = abs(singleArrow-1);

            %Build move buttons in a panel
            obj.move_panel = BakingTray.gui.newGenericGUIPanel([5,188,270,230], obj.hFig);

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
                'String',obj.xyJogSizes.fine.small, ...
                'Callback',@obj.updateJogProperties);

            obj.editBox.largeStepSizeXY=uicontrol('Parent', obj.move_panel, ... 
                'Position', [yButtonR firstButtonH+101 stepEditSize], ...
                'Style','edit', ...
                'Tag','XY||large', ...
                'TooltipString','Size of large X/Y jog motions in mm', ...
                'String',obj.xyJogSizes.fine.large, ...
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
                'String',obj.zJogSizes.fine.small, ...
                'Callback',@obj.updateJogProperties);

            obj.editBox.largeStepSizeZ=uicontrol('Parent', obj.move_panel, ... 
                'Position', [zButtonR firstButtonH+101 stepEditSize], ...
                'Style','edit', ...
                'Tag','Z||large', ...
                'TooltipString','Size of large Z jog motions in mm', ...
                'String',obj.zJogSizes.fine.large, ...
                'Callback',@obj.updateJogProperties);


            %TODO: Add coarse/fine checkbox

            %Add text entry boxes for absolute moves
            obj.absMove_panel = BakingTray.gui.newGenericGUIPanel([130,14,80,83], obj.move_panel);

            buttonRowPos=25; 
            absPosSize=[45,20];
            commonEditBoxProps={'Parent', obj.absMove_panel, 'Style','edit'};

            obj.editBox.xPos=uicontrol(commonEditBoxProps{:}, ...
                'Position', [buttonRowPos 55 absPosSize], ...
                'TooltipString','Current X position and absolute move command', ...
                'String', sprintf('%0.3f',obj.model.xAxis.axisPosition),...
                'Tag','xAxis',...
                'Callback', @obj.executeAbsoluteMotion);
            obj.editBox.yPos=uicontrol(commonEditBoxProps{:}, ...
                'Position', [buttonRowPos 30 absPosSize], ...
                'TooltipString','Current Y position and absolute move command', ...
                'String', sprintf('%0.3f',obj.model.yAxis.axisPosition),...
                'Tag','yAxis',...
                'Callback', @obj.executeAbsoluteMotion);
            obj.editBox.zPos=uicontrol(commonEditBoxProps{:}, ...
                'Position', [buttonRowPos 5 absPosSize], ...
                'TooltipString','Current Z position and absolute move command', ...
                'String', sprintf('%0.3f',obj.model.zAxis.axisPosition),...
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


            %Move to sample button
            obj.moveToSample_button=uicontrol('Parent', obj.move_panel, ...
                'Units','Pixels',...
                'Position', [2, 201, 57, 25], ...
                'String', 'To Sample', ...
                'Callback', @obj.moveToSample);

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

            % ----------------------------
            % cutting and start position buttons
            obj.plan_panel = BakingTray.gui.newGenericGUIPanel([5,97,270,89], obj.hFig);
            commonButtonProps={'Parent',obj.plan_panel,'FontSize',obj.fSize};
            obj.setCuttingPos_button=uicontrol(commonButtonProps{:}, ...
                'Position',[3,59,130,25], ...
                'String','Set blade position', ...
                'Callback', @obj.setCuttingPos_callback );

            obj.setFrontLeft_button=uicontrol(commonButtonProps{:}, ...
                'Position',[3,31,130,25], ...
                'String','Set front/left', ...
                'Callback', @obj.setFrontLeft_callback );

            obj.setVentralMidline_button=uicontrol(commonButtonProps{:}, ...
                'Position',[3,3,130,25], ...
                'String','Set ventral midline', ...
                'Callback', @obj.setVentralMidline_callback );


            % Text edit boxes for the cutting start point and position
            commonXYtextProps={'Color','w', 'FontSize', obj.fSize, 'Units','Pixels'};
            obj.labels.cut_X = annotation(obj.plan_panel, 'textbox', commonXYtextProps{:}, ...
                'Position', [135, 65, 10, 18], 'String', 'X=');

            obj.labels.cut_Y = annotation(obj.plan_panel, 'textbox', commonXYtextProps{:}, ...
                'Position', [135+63, 65, 10, 18], 'String', 'Y=');

            obj.labels.frontLeft_X = annotation(obj.plan_panel, 'textbox', commonXYtextProps{:}, ...
                'Position', [135, 40, 10, 18], 'String', 'X=');

            obj.labels.frontLeft_Y = annotation(obj.plan_panel, 'textbox', commonXYtextProps{:}, ...
                'Position', [135+63, 40, 10, 18], 'String', 'Y=');


            commonXYEditBoxProps={'Parent', obj.plan_panel, 'Style','edit'};

            obj.editBox.cut_X = uicontrol(commonXYEditBoxProps{:}, ...
                'ToolTipString', 'X cutting position', ...
                'Callback', @obj.updateRecipeFrontLeftOrCutPointOnEditBoxChange, ...
                'Position', [159,64,39,17], 'Tag', 'CuttingStartPoint||X');

            obj.editBox.cut_Y = uicontrol(commonXYEditBoxProps{:}, ...
                'Enable','Off', ...
                'ToolTipString', 'Y cutting position', ...
                'Callback', @obj.updateRecipeFrontLeftOrCutPointOnEditBoxChange, ...
                'Position', [159+63,64,39,17], 'Tag', 'CuttingStartPoint||Y');

            obj.editBox.frontLeft_X = uicontrol(commonXYEditBoxProps{:}, ...
                'ToolTipString', 'X front/left position', ...
                'Callback', @obj.updateRecipeFrontLeftOrCutPointOnEditBoxChange, ...
                'Position', [159,39,39,17], 'Tag', 'FrontLeft||X');

            obj.editBox.frontLeft_Y = uicontrol(commonXYEditBoxProps{:}, ...
                'ToolTipString', 'Y front/left position', ...
                'Callback', @obj.updateRecipeFrontLeftOrCutPointOnEditBoxChange, ...
                'Position', [159+63,39,39,17], 'Tag', 'FrontLeft||Y');

            obj.updateCuttingConfigurationText


            % ----------------------------
            %The slice panel
            obj.slice_panel = BakingTray.gui.newGenericGUIPanel([5,5,270,90], obj.hFig);
            sliceButtonCommon={'ForegroundColor','k','FontWeight', 'bold', ...
                            'FontSize', obj.fSize};
            obj.takeSlice_button=uicontrol(sliceButtonCommon{:}, ...
                'Parent', obj.slice_panel, ...
                'Position', [10, 40, 75, 40], ...
                'String', obj.takeSlice_buttonString, ...
                'Callback', @obj.takeOneSlice);

            obj.sliceNtimes_panel = BakingTray.gui.newGenericGUIPanel([100,35,163,48], obj.slice_panel);
            set(obj.sliceNtimes_panel,'BorderType','line', ...
                'BackgroundColor',[1,1,1]*0.11);
            obj.takeNSlices_button=uicontrol(sliceButtonCommon{:}, ...
                'Parent', obj.sliceNtimes_panel, ...
                'Position', [5, 4, 90, 40], ...
                'String', 'Slice N times', ...
                'Callback', @obj.takeNslices);
            obj.editBox.takeNslices = uicontrol('Parent', obj.sliceNtimes_panel, ... 
                'Position', [100, 15 25,20], ...
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
            set(obj.hFig,'KeyPressFcn', {@hMover_KeyPress,obj});


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


            %This timer updates select GUI elements
            obj.prepareViewUpdateTimer = timer;
            obj.prepareViewUpdateTimer.Name = 'prepare view regular updater';
            obj.prepareViewUpdateTimer.Period = obj.prepareViewUpdateInterval;
            obj.prepareViewUpdateTimer.TimerFcn = @(~,~) obj.regularGUIupdater;
            obj.prepareViewUpdateTimer.StopFcn = @(~,~) [];
            obj.prepareViewUpdateTimer.ExecutionMode = 'fixedDelay';
            start(obj.prepareViewUpdateTimer);

        end %Constructor

        function delete(obj)
            %Destructor
            if isa(obj.prepareViewUpdateTimer,'timer')
                stop(obj.prepareViewUpdateTimer)
                delete(obj.prepareViewUpdateTimer)
            end

            obj.hBTview=[];
            delete@BakingTray.gui.child_view(obj);
        end %Constructor


    end %methods


    %Declare function signatures for methods in external files
    methods
        [isSafeToMove,msg]=isSafeToMove(obj,axisToCheckIfMoving)
        executeJogMotion(obj,event,~)
        positionNextToBakingTrayView(obj)
        takeOneSlice(obj,~,~)
        takeNslices(obj,~,~)
        stopAllAxes(obj,~,~)


        function toggleEnable(obj,toggleState)
            % Enables/disables all UI elements. This method is triggered by the callback prepare_view.updateGUIduringAcq so 
            % that it automatically disables the GUI during preview scans and bakes. 
            %
            % Inputs
            % toggleState - should be the string: 'on' or 'off' The function does nothing if this is not the case

            if ~ischar(toggleState)
                return
            end

            if ~strcmpi(toggleState,'on') && ~strcmpi(toggleState,'off')
                return
            end

            obj.stopMotion_button.Enable=toggleState;
            obj.takeSlice_button.Enable=toggleState;
            obj.takeNSlices_button.Enable=toggleState;
            obj.setCuttingPos_button.Enable=toggleState;
            obj.setFrontLeft_button.Enable=toggleState;
            obj.setVentralMidline_button.Enable=toggleState;
            obj.moveToSample_button.Enable=toggleState;

            jogButtons=fields(obj.largeStep);
            for ii=1:length(jogButtons)
                obj.largeStep.(jogButtons{ii}).Enable=toggleState;
                obj.smallStep.(jogButtons{ii}).Enable=toggleState;
            end

            editBoxes=fields(obj.editBox);
            for ii=1:length(editBoxes)
                obj.editBox.(editBoxes{ii}).Enable=toggleState;
            end
            obj.editBox.cut_Y.Enable='Off'; % At least for now, this is always disabled
            switch toggleState
            case 'on'
                start(obj.prepareViewUpdateTimer);
            case 'off'
                stop(obj.prepareViewUpdateTimer);
            end

        end %toggleEnable

    end %Methods




    methods (Hidden)

        function updateJogProperties(obj,event,~)
            %This callback function ensures that the jog properties are kept up to date when the user
            %edits one of the step size values. 

            thisValue=str2double(event.String);

            % Find which axis (XY or Z) and jog type (coarse or fine) and step size (small or large)
            % TODO: The coarse/fine option does not work right now: July 2017
            jogType = strsplit(event.Tag,'||');
            jogAxis = jogType{1};
            jogSmallOrLarge = jogType{2};

            switch jogAxis
                case 'XY'
                    % Check the value we have extracted is numeric (since this the box itself accepts strings)
                    % Reset the value if it was not a number
                    if isnan(thisValue) || thisValue==0
                        set(event, 'String', obj.xyJogSizes.(obj.jogSizeCoarseOrFine).(jogSmallOrLarge) );
                    else
                        obj.xyJogSizes.(obj.jogSizeCoarseOrFine).(jogSmallOrLarge)=thisValue;
                    end
                case 'Z'
                    % Reset the value if it was not a number
                    if isnan(thisValue) || thisValue==0
                        set(event, 'String', obj.zJogSizes.(obj.jogSizeCoarseOrFine).(jogSmallOrLarge) )
                    else
                        obj.zJogSizes.(obj.jogSizeCoarseOrFine).(jogSmallOrLarge)=thisValue;
                    end
                otherwise
                    %This can only happen if the user edits the tag properties in the source code.
                    error('YOU HAVE MODIFIED THE EDIT BOX TAGS IN PREPARE_VIEW. THE GUI CAN NO LONGER FUNCTION.')
            end

            % Switch the values in the small and large step boxes if the small step is larger than the large step
            if str2num(obj.editBox.smallStepSizeXY.String) > str2num(obj.editBox.largeStepSizeXY.String)
                L = obj.editBox.largeStepSizeXY.String;
                S = obj.editBox.smallStepSizeXY.String;
                obj.editBox.smallStepSizeXY.String = L;
                obj.editBox.largeStepSizeXY.String = S;
                obj.xyJogSizes.(obj.jogSizeCoarseOrFine).small = str2num(L);
                obj.xyJogSizes.(obj.jogSizeCoarseOrFine).large = str2num(S);
            end
            if str2num(obj.editBox.smallStepSizeZ.String) > str2num(obj.editBox.largeStepSizeZ.String)
                L = obj.editBox.largeStepSizeZ.String;
                S = obj.editBox.smallStepSizeZ.String;
                obj.editBox.smallStepSizeZ.String = L;
                obj.editBox.largeStepSizeZ.String = S;
                obj.zJogSizes.(obj.jogSizeCoarseOrFine).small = str2num(L);
                obj.zJogSizes.(obj.jogSizeCoarseOrFine).large = str2num(S);
            end

        end %updateJogProperties

        function checkNumSlices(obj,src,~)
            thisValue = str2double(src.String);
            if isnan(thisValue) || thisValue<1
                src.String=obj.lastNslicesValue;
            else
                obj.lastNslicesValue=thisValue;
            end
        end %checkNumSlices

        function checkSliceThicknessEditBoxValue(obj,src,~)
            %Ensures the slice thickness value is within range and paints in green if
            %it matches the recipe value (also see BakingTray.gui.view.updateAllRecipeEditBoxes)
            if nargin>1
                %So if called with no input args it still adjusts the label colour
                thisValue = str2double(src.String);
                if isnan(thisValue) || thisValue<0
                    src.String=obj.lastSliceThickness;
                else
                    obj.lastSliceThickness = thisValue;
                end
                obj.model.recipe.lastSliceThickness=thisValue;
            end
            %Adjust label colour (green if matching recipe)
            if obj.lastSliceThickness == obj.model.recipe.mosaic.sliceThickness
                obj.labels.sliceThickness.Color=obj.readyTextColor;
            else
               obj.labels.sliceThickness.Color='w';
            end
        end %checkSliceThicknessEditBoxValue

        function checkCuttingSpeedEditBoxValue(obj,src,~)
            %Ensures the slice speed value is within range and paints in green if
            %it matches the recipe value (also see BakingTray.gui.view.updateAllRecipeEditBoxes)
            if nargin>1
                %So if called with no input args it still adjusts the label colour
                thisValue = str2double(src.String);
                if isnan(thisValue) || thisValue<0
                    src.String=obj.lastCuttingSpeed;
                else
                    obj.lastCuttingSpeed = thisValue;
                end
            obj.model.recipe.lastCuttingSpeed=thisValue;
            end
            %Adjust label colour (green if matching recipe)
            if obj.lastCuttingSpeed == obj.model.recipe.mosaic.cuttingSpeed
                obj.labels.cuttingSpeed.Color=obj.readyTextColor;
            else
               obj.labels.cuttingSpeed.Color='w';
            end
        end %checkCuttingSpeedEditBoxValue

        function updateElementsDuringSlicing(obj,~,~)
            %Updates the slice once button properties accordin to whether or not the system is slicing
            if obj.model.isSlicing
                obj.takeSlice_button.String='Slicing';
                obj.takeSlice_button.ForegroundColor='r';
                obj.stopMotion_button.String='<html><p align="center">STOP<br/>SLICING</p></html>';
            else
                obj.takeSlice_button.String=obj.takeSlice_buttonString;
                obj.takeSlice_button.ForegroundColor='k';
                obj.stopMotion_button.String='STOP';
            end
        end %updateElementsDuringSlicing

        function updateCuttingConfigurationText(obj,~,~)
            % Updates the cutting config edit boxes. This method is run once in the
            % constructor, whenever one of the three buttons in the plan panel
            % are pressed, by BakingTray.gui.view whenever the recipe is updated. 
            % It's also a callback function run if the user edits the F/L or cut points.
            R = obj.model.recipe;
            if isempty(R)
                return
            end

            C=R.CuttingStartPoint;
            obj.editBox.cut_X.String = sprintf('%0.2f', round(C.X,2));
            obj.editBox.cut_Y.String = sprintf('%0.2f', round(C.Y,2));

            F=R.FrontLeft;
            obj.editBox.frontLeft_X.String = sprintf('%0.2f', round(F.X,2));
            obj.editBox.frontLeft_Y.String = sprintf('%0.2f', round(F.Y,2));

        end %updateCuttingConfigurationText

        function executeAbsoluteMotion(obj,event,~)
            % Execute motion on the axis object that we determine from the tac of the absolute motion edit box
            motionAxisString=event.Tag;
            axisToMove=obj.model.(motionAxisString);
            if ~obj.isSafeToMove(axisToMove)
                return
            end

            %Strip problematic non-numeric characters
            moveString=event.String;
            moveString=regexprep(moveString,'-+','-'); %Don't allow multiple minus signs
            event.String=moveString;
            moveBy=str2double(moveString);
            %if it's not a number, then do nothing
            if isnan(moveBy)
                success=false;
            else
                success=axisToMove.absoluteMove(moveBy); %returns false if an out of range motion was requested
            end

            if success==false
                event.ForegroundColor='r'; %The number will briefly flash red
            end

            %Now read back the axis position. This will correct cases where, say, the axis did not move but the 
            %text label doesn't reflect this. 
            pause(0.1)
            pos=axisToMove.axisPosition;
            if success==false %if there was no motion the box won't update so we have to force it                                
                event.String=sprintf('%0.3f',round(pos,3));
                event.ForegroundColor='k';
            end
        end

        function setCuttingPos_callback(obj,~,~)
            % Runs when the set cutting start point button is pressed
            obj.model.recipe.setCurrentPositionAsCuttingPosition;
            obj.updateCuttingConfigurationText;
        end % setCuttingPos_callback

        function setVentralMidline_callback(obj,~,~)
            % Runs when the set ventral midline button is pressed
            obj.model.recipe.setFrontLeftFromVentralMidLine;
            obj.updateCuttingConfigurationText;
        end % setVentralMidline_callback

        function setFrontLeft_callback(obj,~,~)
            % Runs when the set front/left button is pressed
            obj.model.recipe.setCurrentPositionAsFrontLeft;
            obj.updateCuttingConfigurationText;
        end % setFrontLeft_callback

        function updateRecipeFrontLeftOrCutPointOnEditBoxChange(obj,src,~)
            tokens = strsplit(src.Tag,'||');
            obj.model.recipe.(tokens{1}).(tokens{2}) = str2num(src.String);
        end % updateRecipeFrontLeftOrCutPointOnEditBoxChange



        %Update methods for motion axis boxes and the timer update method
        function regularGUIupdater(obj,~,~)
            %Timer callback function to update GUI components regularly
            obj.updateXaxisEditBox;
            obj.updateYaxisEditBox;
            obj.updateZaxisEditBox;
        end %regularGUIupdater

        function updateXaxisEditBox(obj,~,~)
            pos=round(obj.model.xAxis.axisPosition,3);
            if obj.lastXpos ~= pos || obj.model.xAxis.isMoving
                obj.lastXpos=pos;
                if abs(pos)<0.005
                    pos=0;
                end
                obj.editBox.xPos.String=sprintf('%0.3f',pos);
            end
        end %updateXaxisEditBox

        function updateYaxisEditBox(obj,~,~)
            pos=round(obj.model.yAxis.axisPosition,3);
            if obj.lastYpos ~= pos || obj.model.yAxis.isMoving
                obj.lastYpos=pos;
                if abs(pos)<0.005
                    pos=0;
                end
                obj.editBox.yPos.String=sprintf('%0.3f',pos);
            end
        end %updateYaxisEditBox

        function updateZaxisEditBox(obj,~,~)
            pos=round(obj.model.zAxis.axisPosition,3);
            if obj.lastZpos ~= pos || obj.model.zAxis.isMoving
                obj.lastZpos=pos;
                obj.editBox.zPos.String=sprintf('%0.3f',pos);
            end
        end %updateZaxisEditBox

        function updateGUIduringAcq(obj,~,~)
            %During acquisition the GUI is disabled
            if obj.model.acquisitionInProgress
                obj.toggleEnable('off')
            else
                obj.toggleEnable('on')
            end
        end %updateGUIduringAcq

    end %hidden methods
end


function hMover_KeyPress(~, eventdata, obj)
    key=eventdata.Key;
    ctrlMod=ismember('shift', eventdata.Modifier);
   
    if ctrlMod
        stepSize = 'largeStep';
    else
        stepSize = 'smallStep';
    end
    switch key
        case 'a' 
            runCallBack(obj.(stepSize).left)
        case 'd'
            runCallBack(obj.(stepSize).right)
        case 'w'
            runCallBack(obj.(stepSize).away)
        case 's'
            runCallBack(obj.(stepSize).towards)
        case 'q'
            runCallBack(obj.(stepSize).up)
        case 'e'
            runCallBack(obj.(stepSize).down)
        otherwise
    end

end


function runCallBack(buttonObj)
    C=get(buttonObj,'Callback');
    C(get(buttonObj));
end

