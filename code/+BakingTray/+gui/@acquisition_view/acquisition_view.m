classdef acquisition_view < BakingTray.gui.child_view
    % BakingTray.gui.acquisition_vies
    %
    % This class defines the GUI which shows the sample preview

    properties
        imageAxes %The preview image sits here
        compassAxes %This houses the compass-like indicator 
        
        sectionImage %Reference to the Image object (the image axis child which displays the image)

        doSectionImageUpdate=true %if false we don't update the image
        updatePreviewEveryNTiles=10 % Update the preview image each time a multiple of updatePreviewEveryNTiles has been acquired

        verbose=false % If true, we print to screen callback actions and other similar things that may be slowing us down
    end


    properties (SetObservable,Transient)
        plotOverlayHandles   % All plotted objects laid over the image should keep their handles here
    end %close hidden transient observable properties

    properties (Hidden,SetAccess=private)
        statusPanel %The buttons and panals at the top of the window are kept here
        statusText  %The progress text

        chanToShow=1
        depthToShow=1
        cachedEndTimeStructure % Because the is slow to generate and we don't want to produce it on each tile (see updateStatusText)

        %This button initiate bake and then switches to being a stop button
        button_BakeStop
        buttonSettings_BakeStop %Structure that contains the different settings for the two button states

        %The pause buttons and its settings (for enable/disable)
        button_Pause
        buttonSettings_Pause 

        depthSelectPopup
        channelSelectPopup

        button_runAutoThresh
        button_previewScan

        button_zoomIn
        button_zoomOut
        button_zoomNative
        button_drawBox

        checkBoxLaserOff
        checkBoxCutLast

    end %close hidden private properties


    % Declare hidden methods in separate files
    methods (Hidden)
        buildFigure(obj)    % Called once by the constructor
        setupListeners(obj) % Called once by the constructor

        % Callbacks
        updateSectionImage(obj,~,~,forceUpdate)

        % Callbacks in direct response to user actions
        startPreviewScan(obj,~,~)
        stop_callback(obj,~,~)
        bake_callback(obj,~,~)
        pause_callback(obj,~,~)
        updateBakeButtonState(obj,~,~)

        areaSelector(obj,~,~)
        imageZoomHandler(obj,src,~)

        setDepthToView(obj,~,~)
        setChannelToView(obj,~,~)

    end

    methods
        getThresholdAndOverlayGrid(obj,~,~)
        spawnTilePickerWindow(obj)
    end


    methods
        function obj = acquisition_view(model,parentView)
            obj = obj@BakingTray.gui.child_view;

            if nargin>0
                %TODO: all the obvious checks needed
                obj.model = model;
            else
                fprintf('Can''t build acquisition_view: please supply a BT object\n');
                return
            end

            if nargin>1
                obj.parentView=parentView;
            end

            obj.buildFigure
            obj.setupListeners

            if obj.model.isScannerConnected && obj.model.scanner.isAcquiring
                obj.model.scanner.abortScanning
            end

            % Set Z-settings so if user wishes to press Grab in ScanImage to check their settings, this is easy
            % TODO: in future we might wish to make this more elegant, but for now it should work
            obj.statusText.String = '** Applying settings to scanner **';
            if isa(obj.model.scanner,'SIBT')
                obj.model.scanner.applyZstackSettingsFromRecipe;
            end
            obj.statusText.Color = 'w';
            obj.updateStatusText;
        end

        function delete(obj)
            %obj.parentView.enableDisableThisView('on'); %TODO: remove if all works
            obj.parentView.updateStatusText; %Resets the approx time for sample indicator
            delete@BakingTray.gui.child_view(obj);
        end

    end % methods



    % Short hidden methods 
    methods (Hidden)
        function setUpImageAxes(obj)
            % Add a blank images to the image axes
            blankImage = squeeze(obj.model.lastPreviewImageStack(:,:,obj.depthToShow,obj.chanToShow));

            blankImage(:) = 0;

            obj.sectionImage=imagesc(blankImage,'parent',obj.imageAxes);

            set(obj.imageAxes,... 
                'DataAspectRatio',[1,1,1],...
                'Color', 'k', ...
                'XTick',[],...
                'YTick',[],...
                'YDir','normal',...
                'Box','on',...
                'LineWidth',1,...
                'XColor','w',...
                'YColor','w')
            set(obj.imageAxes.YAxis,'Direction','Reverse'); % TODO-- buildFigure also does this. But has to be here or work of buildfigure gets undone. Buildfigure should call this!
            set(obj.hFig,'Colormap', gray(256))
            obj.overlayStageBoundariesOnImage
        end %setUpImageAxes

        function populateDepthPopup(obj)
            % BakingTray.gui.acquisition_view.populateDepthPopup
            %
            % This callback runs when the user changes the number of depths to be 
            % acquired. It is called via recipeListener. 
            % It is also called in obj.buildFigure and obj.bake_callback. It adds the correct 
            % number of optical planes (depths) to the depths popup so the user 
            % can select which plane they want to view.

            opticalPlanes_str = {};
            for ii=1:obj.model.recipe.mosaic.numOpticalPlanes
                opticalPlanes_str{end+1} = sprintf('Depth %d',ii);
            end
            if length(opticalPlanes_str)>1 && ~isempty(obj.model.scanner.getChannelsToDisplay)
                obj.depthSelectPopup.String = opticalPlanes_str;
                obj.depthSelectPopup.Enable='on';
            else
                obj.depthSelectPopup.String = '1';
                obj.depthSelectPopup.Enable='off';
            end
        end %populateDepthPopup

    end %close hidden methods


    % Short callbacks. Particularly those for updating the GUI
    methods(Hidden)

        function recipeListener(obj,~,~)
            % Runs when the recipe is updated
            obj.populateDepthPopup

            % Disable the auto-thresh button if we aren't in auto-thresh mode
            if ~strcmp(obj.model.recipe.mosaic.scanmode,'tiled: auto-ROI')
                obj.button_runAutoThresh.Enable='off';
            else
                obj.button_runAutoThresh.Enable='on';
            end

            obj.overlayThreshBorderOnImage %Handles removal and addition of the edge guide
        end

        function updateGUIonResize(obj,~,~)
            % Runs when the figure window is resized in order to keep the panels and so on
            % in the required positions
            figPos=obj.hFig.Position;

            %Keep the status panel at the top of the screen and in the centre
            statusPos=obj.statusPanel.Position;
            delta=figPos(3)-statusPos(3); %The number of pixels not covered by the status bar
            obj.statusPanel.Position(1) = round(delta/2);
            obj.statusPanel.Position(2) = figPos(4)-statusPos(4); % Keep at the top

            % Allow the image axes to fill the rest of the space
            imAxesPos=obj.imageAxes.Position;
            obj.imageAxes.Position(3)=figPos(3)-imAxesPos(1)*2+2;
            obj.imageAxes.Position(4)=figPos(4)-statusPos(4)-imAxesPos(2)*2+2;

            pos=plotboxpos(obj.imageAxes);
            obj.compassAxes.Position(1:2) = pos(1:2)+[pos(3)*0.01,pos(4)*0.01];
        end %updateGUIonResize


        function indicateCutting(obj,~,~)
            % Changes GUI elements accordingly during cutting
            if obj.verbose
                fprintf('In acquisition_view.indicateCutting callback\n')
            end
            if obj.model.isSlicing
                obj.statusText.String=' ** CUTTING SAMPLE **';

                % TODO: I think these don't work. bake/stop isn't affected and pause doesn't come back. 
                %obj.button_BakeStop.Enable='off';
                %obj.button_Pause.Enable='off';
            else
                obj.updateStatusText
                %obj.updateBakeButtonState  % TODO: why is this here?
                %obj.updatePauseButtonState % TODO: why is this here?
            end
        end %indicateCutting


        function updateStatusText(obj,~,~)
            % Update the text in the top left of the acquisition view if we are in an acquisition
            % This is called when currentSectionNumber updates
            if obj.verbose, fprintf('In acquisition_view.updateStatusText callback\n'), end

            % We only want to run this on the first tile of each section. Faster this way.
            if obj.model.currentTilePosition==1 || isempty(obj.cachedEndTimeStructure)
                if obj.verbose, fprintf('Caching end time in acquisition_view object\n'), end
                obj.cachedEndTimeStructure=obj.model.estimateTimeRemaining;
            end

            obj.statusText.String = sprintf(['Finish time: %s\nSection=%03d/%03d'], ...
                    obj.cachedEndTimeStructure.expectedFinishTimeString, ...
                    obj.model.currentSectionNumber, ...
                    obj.model.recipe.mosaic.numSections + obj.model.recipe.mosaic.sectionStartNum - 1);
        end %updateStatusText


        function updatePauseButtonState(obj,~,~)
            if obj.verbose, fprintf('In acquisition_view.updatePauseButtonState callback\n'), end

            if ~obj.model.acquisitionInProgress
                set(obj.button_Pause, obj.buttonSettings_Pause.disabled{:})

            elseif obj.model.acquisitionInProgress && ~obj.model.scanner.acquisitionPaused
                set(obj.button_Pause, obj.buttonSettings_Pause.enabled{:})

            elseif obj.model.acquisitionInProgress && obj.model.scanner.acquisitionPaused
                set(obj.button_Pause, obj.buttonSettings_Pause.resume{:})
            end

            if obj.model.isSlicing
                % If we enter this callback because of slicing then disable the button
                % We will re-enter again once slicing and finished and then the above will 
                % hold true and we just won't disable here.
                set(obj.button_Pause, obj.buttonSettings_Pause.disabled{:})
            end
        end %updatePauseButtonState


        function disable_ZoomElementsDuringAcq(obj,~,~)
            % Listener callback to disable the zoom and box buttons during acquisition
            if obj.model.acquisitionInProgress
                obj.button_zoomIn.Enable='off';
                obj.button_zoomOut.Enable='off';
                obj.button_zoomNative.Enable='off';
                obj.button_drawBox.Enable='off';
            else
                obj.button_zoomIn.Enable='on';
                obj.button_zoomOut.Enable='on';
                obj.button_zoomNative.Enable='on';
                obj.button_drawBox.Enable='on';
            end
        end %disable_ZoomElementsDuringAcq


        function closeAcqGUI(obj,~,~)
            %Confirm whether to really quit the GUI. Don't allow it during acquisition 
            if obj.model.acquisitionInProgress
                warndlg('An acquisition is in progress. Stop acquisition before closing GUI.','')
                return
            end

            choice = questdlg(sprintf('Are you sure you want to close the Acquire GUI?\nBakingTray will stay open.'), '', 'Yes', 'No', 'No');

            switch choice
                case 'No'
                    %pass
                case 'Yes'
                    obj.delete
            end
        end %closeAcqGUI


        function updateImageLUT(obj,~,~)
            % BakingTray.gui.acquisition_view.updateImageLUT
            %
            % This calback updates the look-up table in the preview image wehen the user
            % changes associated slider in the ScanImage IMAGE CONTROLS window.

            if obj.verbose, fprintf('In acquisition_view.updateImageLUT callback\n'), end

            if obj.model.isScannerConnected
                thisLut=obj.model.scanner.getChannelLUT(obj.chanToShow);
                obj.imageAxes.CLim=thisLut;
            end
        end %updateImageLUT


        function chooseChanToDisplay(obj)
            % Choose a channel to display as a default: For now just the first channel

            if obj.verbose, fprintf('In acquisition_view.chooseChanToDisplay callback\n'), end

            channelsBeingAcquired = obj.model.scanner.getChannelsToAcquire;
            channelsScannerDisplays = obj.model.scanner.getChannelsToDisplay;

            if isempty(channelsScannerDisplays)
                % Then we can't display anything
                return
            end

            %TODO: we can choose this more cleverly in future
            obj.channelSelectPopup.Value=1;

            obj.setChannelToView
        end %chooseChanToDisplay

        function updateChannelsPopup(obj,~,~)
            % BakingTray.gui.acquisition_view.updateChannelsPopup
            %
            % This calback ensures the channels available in the popup are the same as those
            % available in the scanning software.

            if obj.verbose, fprintf('In acquisition_view.updateChannelsPopup callback\n'), end

            if obj.model.isScannerConnected
                % Active channels are those being displayed, since with resonant scanning
                % if it's not displayed we have no access to the image data. This isn't
                % the case with galvo/galvo, unfortunately, but we'll just proceed like this
                % and hope galvo/galvo works OK.
                activeChannels = obj.model.scanner.getChannelsToDisplay;
                activeChannels_str = {};
                for ii=1:length(activeChannels)
                    activeChannels_str{end+1} = sprintf('Chan %d',activeChannels(ii));
                end

                if ~isempty(activeChannels)
                    if length(activeChannels_str)<obj.channelSelectPopup.Value
                        % Otherwise we will get an error and the UI control will not appear
                        obj.chooseChanToDisplay
                        obj.setChannelToView
                    end
                    obj.channelSelectPopup.String = activeChannels_str;
                    obj.channelSelectPopup.Enable='on';
                else
                    obj.channelSelectPopup.String='NONE';
                    obj.channelSelectPopup.Enable='off';
                end
            end
        end %updateChannelsPopup




        function pointerReporter(obj,~,~)
            % Runs when the mouse is moved over the axis to report its position in stage coordinates. 
            % This is printed as text to the top left of the plot. The callback does not run if an
            % acquisition is in progress or if the plotted image contains only zeros.

            % Report stage position to screen. The reported position is the 
            % top/left tile position.
            if obj.model.acquisitionInProgress || all(obj.sectionImage.CData(:)==0)
                return
            end

            pos=get(obj.imageAxes, 'CurrentPoint');
            xAxisCoord=pos(1,1);
            yAxisCoord=pos(1,2);

            stagePos = obj.model.convertImageCoordsToStagePosition([xAxisCoord,yAxisCoord]);
            obj.statusText.String = sprintf('Stage Coordinates:\nX=%0.2f mm Y=%0.2f mm', stagePos);

        end % pointerReporter

        function previewMoveToPosition(obj,~,sourceHandle)
            % To do: Stage is currently moved so that the clicked position is in
            % the upper corner of the new FOV. Change to center clicked
            % position.
            
            
            % Initiates movement to clicked position in image preview (middle mouse button). 
            % The callback does not run if an
            % acquisition is in progress or if the plotted image contains only zeros.
            
            if obj.model.acquisitionInProgress || all(obj.sectionImage.CData(:)==0)
                return
            end
            
            % Check for click-type, execute only on middle click
            if strcmp(get(sourceHandle.Source.Number,'SelectionType'),'extend')
                % Get current position
                pos=get(obj.imageAxes, 'CurrentPoint');
                xAxisCoord=pos(1,1);
                yAxisCoord=pos(1,2);
                
                stagePos = obj.model.convertImageCoordsToStagePosition([xAxisCoord,yAxisCoord]);
                %Get current FOV and move FOV in middle of mouse click
                stagePos(1) = stagePos(1)+obj.model.recipe.ScannerSettings.FOV_alongColsinMicrons/2/1000;
                stagePos(2) = stagePos(2)+obj.model.recipe.ScannerSettings.FOV_alongRowsinMicrons/2/1000;
                % Move stage
                obj.model.moveXYto(stagePos(1), stagePos(2));
                % Refresh GUI
                obj.model.xAxis.axisPosition();
                obj.model.yAxis.axisPosition();
            end
        end   % previewMoveToPosition
        
        function updateLeaveLaserOn(obj,~,~)
            % Set the leave laser on flag in the model.
            % Responds to checkbox
            obj.model.leaveLaserOn=~obj.checkBoxLaserOff.Value;
        end %updateLeaveLaserOn


        function updateSliceLastSection(obj,~,~)
            % Set the slice last section flag in the model.
            % Responds to checkbox
            obj.model.sliceLastSection=obj.checkBoxCutLast.Value;
        end %updateLeaveLaserOn

    end %close hidden callbacks


end
