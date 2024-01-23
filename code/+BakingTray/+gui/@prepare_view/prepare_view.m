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
        autoTrim_button

        lockZ_checkbox

        setCuttingPos_button
    end

    properties (Hidden)
        % The following properties store GUI panel handles
        move_panel
        slice_panel
        absMove_panel
        plan_panel
        trim_panel

        suppressToolTips=false
        labels=struct

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

        % Default small and large step sizes for the jogs
        defaultSmallStep = 0.1;
        defaultLargeStep = 0.5;
    end
    
    properties (SetObservable,Hidden)
        lastXpos=0
        lastYpos=0
        lastZpos=0
    end

    methods

        function obj=prepare_view(hBT,hBTview)
            obj = obj@BakingTray.gui.child_view;

            if nargin>1
                %If the BT view created this panel, it will provide this argument
                obj.parentView=hBTview;
            end

            %Do not proceed if any components are missing
            msg = hBT.checkForPrepareComponentsThatAreNotConnected;
            if ~isempty(msg)
                fprintf('Not starting BakingTray.gui.prepare_view:\n%s\n',msg)
                obj.delete
            end
            
            %Force user to reference stages before carrying on.
            if hBT.allStagesReferenced == false
                hBTview.referenceStages
                if hBT.allStagesReferenced == false
                     msgbox('There are still non-referenced stages. Not opening prepare GUI.')
                     delete(obj)
                     return
                end
            end
            %Keep a copy of the BT model
            obj.model = hBT;

            obj.buildWindow % Set up the GUI window

            %This timer updates select GUI elements
            obj.prepareViewUpdateTimer = timer;
            obj.prepareViewUpdateTimer.Name = 'prepare view regular updater';
            obj.prepareViewUpdateTimer.Period = obj.prepareViewUpdateInterval;
            obj.prepareViewUpdateTimer.TimerFcn = @(~,~) obj.regularGUIupdater;
            obj.prepareViewUpdateTimer.StopFcn = @(~,~) [];
            obj.prepareViewUpdateTimer.ExecutionMode = 'fixedDelay';


            % Read all stage positions to be extra sure the GUI is up to date
            obj.model.getXpos;
            obj.model.getYpos;
            obj.model.getZpos;    

            % If a cutting position has been set we lock the Z axis
            if isnan(str2num(obj.editBox.cut_X.String))
                obj.lockZ_checkbox.Value=0;
            else
                obj.lockZ_checkbox.Value=1;
            end
            obj.lockZ_callback([],[],true);
        end %Constructor

        function delete(obj)
            %Destructor
            if isa(obj.prepareViewUpdateTimer,'timer')
                stop(obj.prepareViewUpdateTimer)
                delete(obj.prepareViewUpdateTimer)
            end

            delete@BakingTray.gui.child_view(obj); %TODO: this is redundant, I think
        end %Constructor


    end %methods


    %Declare function signatures for methods in external files
    methods
        [isSafeToMove,msg]=isSafeToMove(obj,axisToCheckIfMoving)
        executeJogMotion(obj,src,~)
        positionNextToBakingTrayView(obj)
        takeOneSlice(obj,~,~)
        takeNslices(obj,~,~)
        stopAllAxes(obj,~,~)
        toggleEnable(obj,toggleState)
        autoTrim(obj,~,~)
        resetBladeIfNeeded(obj)
    end %Methods




    methods (Hidden)

        function resetStepSizesToDefaults(obj)
            % this is not a callback function, it simply sets the steps sizes to default values
            obj.xyJogSizes.small = obj.defaultSmallStep;
            obj.xyJogSizes.large = obj.defaultLargeStep;
            obj.zJogSizes.small = obj.defaultSmallStep;
            obj.zJogSizes.large = obj.defaultLargeStep;

            obj.editBox.largeStepSizeXY.String = obj.xyJogSizes.large;
            obj.editBox.smallStepSizeXY.String = obj.xyJogSizes.small;
            obj.editBox.largeStepSizeZ.String = obj.zJogSizes.large;
            obj.editBox.smallStepSizeZ.String = obj.zJogSizes.small;


        end %resetStepSizesToDefaults


        function lockZ(obj)
            % Locks the Z jack
            obj.lockZ_checkbox.Value=1; 
            obj.lockZ_callback;
        end 


        function unLockZ(obj)
            % unlocks the Z jack
            obj.lockZ_checkbox.Value=0;
            obj.lockZ_callback([],[],true);
        end 


        function updateJogProperties(obj,src,~)
            %This callback function ensures that the jog properties are kept up to date when the user
            %edits one of the step size values. 

            thisValue=str2double(src.String);

            % Find which axis (XY or Z) and step size (small or large)
            jogType = strsplit(src.Tag,'||');
            jogAxis = jogType{1};
            jogSmallOrLarge = jogType{2};

            switch jogAxis
                case 'XY'
                    % Check the value we have extracted is numeric (since this the box itself accepts strings)
                    % Reset the value if it was not a number
                    if isnan(thisValue) || thisValue==0
                        set(src, 'String', obj.xyJogSizes.(jogSmallOrLarge) );
                    else
                        obj.xyJogSizes.(jogSmallOrLarge)=thisValue;
                    end
                case 'Z'
                    % Reset the value if it was not a number
                    if isnan(thisValue) || thisValue==0
                        set(src, 'String', obj.zJogSizes.(jogSmallOrLarge) )
                    else
                        obj.zJogSizes.(jogSmallOrLarge)=thisValue;
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
                obj.xyJogSizes.small = str2num(L);
                obj.xyJogSizes.large = str2num(S);
            end
            if str2num(obj.editBox.smallStepSizeZ.String) > str2num(obj.editBox.largeStepSizeZ.String)
                L = obj.editBox.largeStepSizeZ.String;
                S = obj.editBox.smallStepSizeZ.String;
                obj.editBox.smallStepSizeZ.String = L;
                obj.editBox.largeStepSizeZ.String = S;
                obj.zJogSizes.small = str2num(L);
                obj.zJogSizes.large = str2num(S);
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
                obj.autoTrim_button.Enable='off';
                obj.takeSlice_button.String='Slicing';
                obj.takeSlice_button.ForegroundColor='r';
                obj.stopMotion_button.String='<html><p align="center">STOP<br/>SLICING</p></html>';
            else
                obj.autoTrim_button.Enable='on';
                obj.takeSlice_button.String=obj.takeSlice_buttonString;
                obj.takeSlice_button.ForegroundColor='k';
                obj.stopMotion_button.String='STOP';
            end
        end %updateElementsDuringSlicing

        function updateCuttingConfigurationText(obj,~,~)
            % Updates the cutting config edit boxes. This method is run once in the
            % constructor, whenever one of the buttons in the plan panel
            % are pressed, by BakingTray.gui.view whenever the recipe is updated. 
            % It's also a callback function run if the user edits the F/L or cut points.
            R = obj.model.recipe;
            if isempty(R)
                return
            end

            CSP = R.CuttingStartPoint;
            obj.editBox.cut_X.String = sprintf('%0.2f', round(CSP.X,2));

            % Update the cut size
            CS = R.mosaic.cutSize;
            obj.editBox.cutSize_X.String = sprintf('%0.2f', round(CS,2));
        end %updateCuttingConfigurationText

        function executeAbsoluteMotion(obj,src,~)
            % BakingTray.gui.view.executeAbsoluteMotion
            %
            % This callback is run when the user edits one of the absolute
            % motion text entry boxes. It executes motion on the axis object 
            % that we determine from the tag of the absolute motion edit box
            % itself. 
            
             
            motionAxisString=src.Tag;
            axisToMove=obj.model.(motionAxisString);
            if ~obj.isSafeToMove(axisToMove)
                return
            end

            % If any axis is not referenced we ask the user to refence the
            % stages. 
            if obj.model.allStagesReferenced == false
                obj.parentView.referenceStages;
                axisToMove.axisPosition; %Ensure current position is displayed in GUI
                return
            end

            %Strip problematic non-numeric characters
            moveString=src.String;
            moveString=regexprep(moveString,'-+','-'); %Don't allow multiple minus signs
            src.String=moveString;
            moveTo=str2double(moveString);
            %if it's not a number, then do nothing
            if isnan(moveTo)
                success=false;
            else
                if strcmp('zAxis',motionAxisString) && moveTo==0
                    success = obj.model.lowerZstage;
                else
                    success=axisToMove.absoluteMove(moveTo); %returns false if an out of range motion was requested
                end
            end

            if success==false
                src.ForegroundColor='r'; %The number will briefly flash red
            end

            %Now read back the axis position. This will correct cases where, say, the axis did not move but the 
            %text label doesn't reflect this. 
            pause(0.1)
            pos=axisToMove.axisPosition;
            if success==false %if there was no motion the box won't update so we have to force it=
                src.String=sprintf('%0.3f',round(pos,3));
                src.ForegroundColor='k';
            end
            if strcmp(obj.prepareViewUpdateTimer.Running, 'off')
                start(obj.prepareViewUpdateTimer)
            end
        end

        function setCuttingPos_callback(obj,~,~)
            % Runs when the set cutting start point button is pressed
            obj.model.recipe.setCurrentPositionAsCuttingPosition;
            obj.updateCuttingConfigurationText;
        end % setCuttingPos_callback

        function lockZ_callback(obj,~,~,byPassQuestDlg)
            % Run every time the lock-z checkbox changes state.
            % 
            %    function lockZ_callback(obj,~,~,byPassQuestDlg)

            if nargin<4
                byPassQuestDlg = false;
            end

            % Query whether the user really wants to unlock
            if byPassQuestDlg==false && obj.lockZ_checkbox.Value == 0
                obj.lockZ_checkbox.Value=1;
                q_reply = questdlg(['You must not use the sample z-stage to focus since moving ', ...
                    'the z-stage will alter cutting thickness. Are you sure you know what you ', ...
                    'are doing and want to unlock Z?'],...
                    'Are you sure?','Yes','No','No');

                if strcmp(q_reply,'Yes')
                    obj.lockZ_checkbox.Value=0;
                end
            end

            % Runs when the checkbox is checked
            if obj.lockZ_checkbox.Value == 1
                % Stage is locked
                obj.lockZ_checkbox.ForegroundColor = 'r';
                obj.lockZ_checkbox.String='Unlock Z';

                obj.editBox.zPos.Enable='off';
                obj.smallStep.up.Enable='off';
                obj.smallStep.down.Enable='off';
                obj.largeStep.up.Enable='off';
                obj.largeStep.down.Enable='off';
            else
                obj.lockZ_checkbox.ForegroundColor = 'g';
                obj.lockZ_checkbox.String='Lock Z';

                obj.editBox.zPos.Enable='on';
                obj.smallStep.up.Enable='on';
                obj.smallStep.down.Enable='on';
                obj.largeStep.up.Enable='on';
                obj.largeStep.down.Enable='on';
            end
        end %lockZ_callback

        function updateRecipeCutPointOnEditBoxChange(obj,src,~)
            tokens = strsplit(src.Tag,'||');
            obj.model.recipe.(tokens{1}).(tokens{2}) = str2num(src.String);
        end % updateRecipeFrontLeftOrCutPointOnEditBoxChange



        %Update methods for motion axis boxes and the timer update method
        function regularGUIupdater(obj,~,~)
            %Timer callback function to update GUI components regularly
            xMoved = obj.updateXaxisEditBox;
            yMoved = obj.updateYaxisEditBox;
            zMoved = obj.updateZaxisEditBox;
            % If no axes moved we stop the timer
            if ~xMoved && ~yMoved && ~zMoved
                stop(obj.prepareViewUpdateTimer)
            end
        end %regularGUIupdater

        function axisMoved = updateXaxisEditBox(obj,~,~)
            pos=round(obj.model.getXpos,3);
            if obj.lastXpos ~= pos || obj.model.xAxis.isMoving
                obj.lastXpos=pos;
                if abs(pos)<0.005
                    pos=0;
                end
                obj.editBox.xPos.String=sprintf('%0.3f',pos);
                axisMoved = true;
            else
                axisMoved = false;
            end

        end %updateXaxisEditBox

        function axisMoved = updateYaxisEditBox(obj,~,~)
            pos=round(obj.model.getYpos,3);
            if obj.lastYpos ~= pos || obj.model.yAxis.isMoving
                obj.lastYpos=pos;
                if abs(pos)<0.005
                    pos=0;
                end
                obj.editBox.yPos.String=sprintf('%0.3f',pos);
                axisMoved = true;
            else
                axisMoved = false;
            end
        end %updateYaxisEditBox

        function axisMoved = updateZaxisEditBox(obj,~,~)
            pos=round(obj.model.getZpos,3);
            if pos==0
                pos = abs(pos);
            end
                
            if obj.lastZpos ~= pos || obj.model.zAxis.isMoving
                obj.lastZpos=pos;
                obj.editBox.zPos.String=sprintf('%0.3f',pos);
                axisMoved = true;
            else
                axisMoved = false;
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
