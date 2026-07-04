classdef laser_view < BakingTray.gui.child_view


    properties
        statusPanel
        powerIndicator
        powerText
        shutterIndicator
        shutterText
        modelockIndicator
        modelockText
        connectionIndicator
        connectionText
        laserPowerText

        buttonOnOff
        buttonShutter
        editWavelength
        currentWavelengthText
    end

    properties(Hidden)
        currentWavelengthString='Current Wavelength: %d nm' %Used in the sprintf for the current wavelength
        setWavelengthLabel
    end


    %Declare function signatures for methods in external files
    methods

    end


    methods
        function obj = laser_view(hBT,parentView)
            obj = obj@BakingTray.gui.child_view;

            if nargin>0
                %TODO: all the obvious checks needed
                obj.model = hBT;
            else
                fprintf('Can''t build laser_view: please supply hBT as an input argument\n');
                return
            end

            if nargin>1
                obj.parentView=parentView;
            end

            obj.hFig = BakingTray.gui.newGenericGUIFigureWindow('BakingTray_laser');

            % Closing the figure closes the laser view object
            set(obj.hFig,'CloseRequestFcn', @obj.closeComponentView)

            %Resize the figure window
            pos=get(obj.hFig, 'Position');
            pos(3:4)=[220,250]; %Set the window size
            if isempty(obj.model.laser.friendlyName)
                set(obj.hFig, 'Position',pos, 'Name', 'Laser Control')
            else
                set(obj.hFig, 'Position',pos, 'Name', obj.model.laser.friendlyName)
            end

            %Add some listeners to monitor properties on the laser component
            fprintf('Setting up laser GUI listeners\n')
            obj.listeners{1}=addlistener(obj.model.laser, 'targetWavelength', 'PostSet', @obj.setWavelengthEditPanelToNewTargetWaveLength);
            obj.listeners{2}=addlistener(obj.model.laser, 'currentPower_mW','PostSet', @obj.updatePowerText);
            obj.listeners{3}=addlistener(obj.model.laser, 'isLaserShutterOpen','PostSet', @obj.updateGUI);
            obj.listeners{4}=addlistener(obj.model.laser, 'isLaserModeLocked','PostSet', @obj.updateGUI);
            obj.listeners{5}=addlistener(obj.model.laser, 'isLaserConnected','PostSet', @obj.updateGUI);
            obj.listeners{6}=addlistener(obj.model.laser, 'isLaserOn','PostSet', @obj.updateGUI);
            obj.listeners{7}=addlistener(obj.model.laser, 'currentWavelength','PostSet', @obj.updateCurrentWavelength);

            %Disable potentially dangerous operations during acquisition
            obj.listeners{8}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.updateAcqMode);



            % Make the status panel
            obj.statusPanel = BakingTray.gui.newGenericGUIPanel([7.6 8.5 206.8 137.5], obj.hFig);
            indicatorsLeftPos=115;
            obj.powerIndicator = obj.makeRectangle(obj.statusPanel,[indicatorsLeftPos,110]);
            obj.powerText = obj.makeTextLabel(obj.statusPanel,[0 109, 110 20],'Power: OFF');
            set(obj.powerText, 'HorizontalAlignment', 'Right');

            obj.shutterIndicator   = obj.makeRectangle(obj.statusPanel,[indicatorsLeftPos,90]);
            obj.shutterText = obj.makeTextLabel(obj.statusPanel,[0, 89, 110 20],'Shutter Closed');
            set(obj.shutterText, 'HorizontalAlignment', 'Right');

            obj.modelockIndicator = obj.makeRectangle(obj.statusPanel,[indicatorsLeftPos,70]);
            obj.modelockText = obj.makeTextLabel(obj.statusPanel,[0, 69, 110 20],'Modelock: NO');
            set(obj.modelockText, 'HorizontalAlignment', 'Right')

            obj.connectionIndicator = obj.makeRectangle(obj.statusPanel,[indicatorsLeftPos,50]);
            obj.connectionText = obj.makeTextLabel(obj.statusPanel,[0, 49, 110 20],'Connected: NO');
            set(obj.connectionText, 'HorizontalAlignment', 'Right');

            % The text that reports the current laser power
            obj.laserPowerText = obj.makeTextLabel(obj.statusPanel,[0, 29, 180 20],'Output Power: 0 mW');

            % Buttons
            obj.buttonOnOff=uicontrol(...
                'Parent', obj.hFig, ...
                'Position', [10, 220, 75, 25], ...
                'FontSize', obj.fSize, ...
                'FontWeight', 'bold', ...
                'String', 'Turn On', ...
                'Callback', @obj.onOffButtonCallBack);

            obj.buttonShutter=uicontrol(...
                'Parent', obj.hFig, ...
                'Position', [100, 220, 100, 25], ...
                'FontSize', obj.fSize, ...
                'FontWeight', 'bold', ...
                'String', 'Open Shutter', ...
                'Callback', @obj.shutterButtonCallBack);


            % - - - - - - - - -
            % Wavelength
            %Get the wavelength
            fprintf('Checking laser is connected\n')
            if obj.model.laser.isControllerConnected
                fprintf('Doing first read of wavelength\n')
                currentWavelength=obj.model.laser.readWavelength;
            else
                currentWavelength=0;
            end

            obj.editWavelength=uicontrol(...
                'Parent', obj.hFig, ...
                'Style','edit', ...
                'Position', [125, 195, 50, 20], ...
                'FontSize', obj.fSize, ...
                'String', currentWavelength, ...
                'Callback', @obj.setWavelengthEditPanel);

            obj.setWavelengthLabel=obj.makeTextLabel(obj.hFig,[5, 195, 155 20],'Target Wavelength:');
            obj.currentWavelengthText = obj.makeTextLabel(obj.hFig,[5, 170, 195, 20],sprintf(obj.currentWavelengthString,currentWavelength));



            %Set the GUI elements to reflect the current state of the laser
            obj.model.laser.isPoweredOn; %Not pretty, but we run this to ensure the properties are set correctly
            obj.updateGUI;
            obj.updateAcqMode; %Ensure buttons are in the right state (enabled/disabled)

            %Set the target wavelength to equal the current wavelength
            obj.model.laser.targetWavelength=obj.model.laser.currentWavelength;


        end %constructor

        function delete(obj)
            %Flush the buffer on the laser (just in case)
            hLaserComms = obj.model.laser.hC;
            if ~isempty(hLaserComms) && isobject(hLaserComms) && isvalid(hLaserComms)
                if isa(hLaserComms,'serial')
                    flushinput(hLaserComms) % legacy serial (e.g. chameleon, tiberius)
                else
                    flush(hLaserComms) % serialport (e.g. maitai)
                end
            end

            cellfun(@delete,obj.listeners)
            delete@BakingTray.gui.child_view(obj);
        end


        % UI Callback functions
        function setWavelengthEditPanel(obj,~,~)
            %Runs when the user enters a new value in the panel
            if ~obj.model.laser.isLaserOn
                warndlg('Laser is powered off','')
                set(obj.editWavelength,'String',obj.model.laser.targetWavelength)
                return
            end

            newValue=get(obj.editWavelength,'String');

            newValue=str2double(newValue);
            if isempty(newValue) || isnan(newValue)
                %If it wasn't numeric, set it back to what it was before
                fprintf('Not a valid wavelength value\n');
                set(obj.editWavelength,'String',obj.model.laser.targetWavelength)
                return
            end

            [inRange,msg]=obj.model.laser.isTargetWavelengthInRange(newValue);
            if ~inRange
                warndlg(msg,'')
                return
            end

            %Will trigger setWavelengthEditPanelToNewTargetWaveLength
            obj.model.laser.setWavelength(newValue);
            obj.model.laser.isModeLocked; %TODO: should this still be here? RAAC 26/07/04
        end


        % API-triggered callbacks
        function setWavelengthEditPanelToNewTargetWaveLength(obj,~,~)
            %Called when the laser's target wavelength property changes
            set(obj.editWavelength,'String',obj.model.laser.targetWavelength)

            % The wavelength has now stabilised so we can apply laser calibration to the scanner.
            % If the user has created calibration files to convert laser analog voltage to
            % mW at the objective, these are now loaded and applied to the scanner.
            obj.model.applyLaserCalibrationToScanner;
        end


        function h = makeRectangle(~,parentObj,pos)
            h = annotation(...
                parentObj, 'rectangle', ...
                'Units', 'Pixels', ...
                'Position', [pos,15,15], ...
                'Color',[1,1,1]*0.8, ...
                'FaceColor','r');
        end


        function h = makeTextLabel(obj,parentObj,pos,txt)
            h = annotation(...
                parentObj, 'textbox', ...
                'Units', 'Pixels', ...
                'Position', pos , ...
                'EdgeColor', 'None', ...
                'Color', 'w', ...
                'FontWeight', 'Bold', ...
                'FontSize', obj.fSize, ...
                'String', txt);
        end

    end


    methods (Hidden)
        function updateCurrentWavelength(obj,~,~)
            W=obj.model.laser.currentWavelength;
            set(obj.currentWavelengthText,'String',sprintf(obj.currentWavelengthString,round(W)))
        end % updateCurrentWavelength


        %The following methods are used to update GUI elements upon certain events happening
        function onOffButtonCallBack(obj,~,~)
            % Turns the laser on or off. Which it does depends on the current state of the laser.
            % GUI elements are updated via callbacks.

            isPoweredOn = obj.model.laser.isPoweredOn;

            if isPoweredOn
                obj.model.laser.turnOff;

                % Because sometimes some elements get stick as on
                pause(0.5)
                obj.updateGUI
            else
                obj.model.laser.turnOn;
            end

        end % onOffButtonCallBack


        function shutterButtonCallBack(obj,~,~)
            if obj.model.laser.isLaserShutterOpen==true
                obj.model.laser.closeShutter;
            elseif obj.model.laser.isLaserShutterOpen==false
                obj.model.laser.openShutter;
            end
        end


        function updateShutterElements(obj,~,~)
            if obj.model.laser.isLaserShutterOpen==true
                set(obj.buttonShutter, 'String', 'Close Shutter')
                set(obj.shutterText, 'String', 'Shutter Opened')
                set(obj.shutterIndicator, 'FaceColor', 'g')
            elseif obj.model.laser.isLaserShutterOpen==false
                set(obj.buttonShutter, 'String', 'Open Shutter')
                set(obj.shutterText, 'String', 'Shutter Closed')
                set(obj.shutterIndicator, 'FaceColor', 'r')
            end
        end %updateShutterElements


        function updateModeLockElements(obj,~,~)
            if obj.model.laser.isLaserModeLocked==true
                set(obj.modelockIndicator, 'FaceColor', 'g')
                set(obj.modelockText, 'String', 'Modelock: YES')
            elseif obj.model.laser.isLaserModeLocked==false
                set(obj.modelockIndicator, 'FaceColor', 'r')
                set(obj.modelockText, 'String', 'Modelock: NO')
            end
        end %updateModeLockElements


        function updateLaserConnectedElements(obj,~,~)
            if obj.model.laser.isLaserConnected==true
                set(obj.connectionIndicator, 'FaceColor', 'g')
                set(obj.connectionText, 'String', 'Connected: YES')
            elseif obj.model.laser.isLaserConnected==false
                set(obj.connectionIndicator, 'FaceColor', 'r')
                set(obj.connectionText, 'String', 'Connected: NO')
            end
        end %updateLaserConnectedElements


        function updateLaserOnElements(obj)
            % Update laser on or off elements
            %
            % laser_view.updateLaserOnElements
            %
            % NOTES
            % If the laser is reported as being off but is also reported as being
            % mode-locked, then double-check whether or not it is on. This
            % function is called via callbacks that are triggered by the
            % laser on or off state from the laser object in the model.
            % DO NOT read the stat of the laser here: it can cause
            % problems.

            if obj.model.laser.isLaserOn==true
                set(obj.buttonOnOff, 'String', 'Turn Off')
                set(obj.powerIndicator, 'FaceColor', 'g')
                set(obj.powerText, 'String', 'Power: ON')
            elseif obj.model.laser.isLaserOn==false
                set(obj.buttonOnOff, 'String', 'Turn On')
                set(obj.powerIndicator, 'FaceColor', 'r')
                set(obj.powerText, 'String', 'Power: OFF')
            end
        end %updateLaserOnElements


        function updatePowerText(obj,~,~)
            powerIn_mW = round(obj.model.laser.currentPower_mW);
            set(obj.laserPowerText,'String', sprintf('Output Power: %d mW',powerIn_mW))
        end %updatePowerText


        function updateGUI(obj,~,~)
            obj.updateShutterElements;
            obj.updateModeLockElements;
            obj.updateLaserConnectedElements;
            obj.updateLaserOnElements;
        end %updateGUI


        function updateAcqMode(obj,~,~)
            %Disable shutter and on buttons during acquisition
            if obj.model.acquisitionInProgress
                obj.buttonShutter.Enable='off';
                obj.buttonOnOff.Enable='off';
            else
                obj.buttonShutter.Enable='on';
                obj.buttonOnOff.Enable='on';
            end
        end %updateAcqMode

    end %end hidden methods

end
