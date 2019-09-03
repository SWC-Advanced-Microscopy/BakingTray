classdef acquisition_view < BakingTray.gui.child_view
    % BakingTray.gui.acquisition_vies
    %
    % This class defines the GUI which shows the sample preview

    properties
        imageAxes %The preview image sits here
        compassAxes %This houses the compass-like indicator 

        statusPanel %The buttons and panals at the top of the window are kept here
        statusText  %The progress text
        sectionImage %Reference to the Image object (the image axis child which displays the image)

        doSectionImageUpdate=true %if false we don't update the image


        %This button initiate bake and then switches to being a stop button
        button_BakeStop
        buttonSettings_BakeStop %Structure that contains the different settings for the two button states

        %The pause buttons and its settings (for enable/disable)
        button_Pause
        buttonSettings_Pause 

        depthSelectPopup
        channelSelectPopup

        button_previewScan

        button_zoomIn
        button_zoomOut
        button_zoomNative
        button_drawBox

        checkBoxLaserOff
        checkBoxCutLast

        verbose=false % If true, we print to screen callback actions and other similar things that may be slowing us down
    end

    properties (SetObservable,Transient)
        previewImageData=[]  %This 4D matrix holds the preview image (pixel rows, pixel columns, z depth, channel)
        previewTilePositions %This is where the tiles will go (we take into account the overlap between tiles: see .initialisePreviewImageData)
    end %close hidden transient observable properties

    properties (Hidden,SetAccess=private)
        chanToShow=1
        depthToShow=1
        cachedEndTimeStructure % Because the is slow to generate and we don't want to produce it on each tile (see updateStatusText)
        rotateSectionImage90degrees=true; %Ensure the axis along which the blade cuts is is the image x axis. 

        % Cached/stored settings
        % Log front/left pos when preview is taken so we don't change coords if user updates front/left after imaging
        frontLeftWhenPreviewWasTaken = struct('X',[],'Y',[]);

    end %close hidden private properties



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
            panelHeight=40;
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

            %Make the image axes (also see obj.setUpImageAxes)
            obj.imageAxes = axes('parent', obj.hFig, 'Units','pixels', 'Color', 'k',...
                'Position',[3,2,minFigSize(1)-4,minFigSize(2)-panelHeight-4]);


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
                'Position', [205, 2, 60, 32], ...
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
                'Position', [270, 2, 60, 32], ...
                'Units','Pixels', ...
                'FontSize', obj.fSize, ...
                'FontWeight', 'bold',...
                'Callback', @obj.pause_callback);
            set(obj.button_Pause, obj.buttonSettings_Pause.disabled{:})


            %Pop-ups for selecting which depth and channel to show
            % Create pop-up menu
            obj.depthSelectPopup = uicontrol('Parent', obj.statusPanel, 'Style', 'popup',...
           'Position', [340, 0, 70, 30], 'String', 'depth', 'Callback', @obj.setDepthToView,...
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
            obj.initialisePreviewImageData(tp);
            obj.setUpImageAxes;
            drawnow


            % Populate the depth popup
            obj.populateDepthPopup
            obj.setDepthToView; %Ensure that the property is set to a valid depth (it should be anyway)

            obj.channelSelectPopup = uicontrol('Parent', obj.statusPanel, 'Style', 'popup',...
                'Position', [420, 0, 70, 30], 'String', '', 'Callback', @obj.setChannelToView,...
                'Interruptible', 'off');

            % Add the channel names. This is under the control of a listener in case the user makes a 
            % change in ScanImage after the acquisition_view GUI has opened.
            obj.updateChannelsPopup
            obj.setChannelToView % Ensure that the property is set to a valid channel


            % Report the cursor position with a callback function
            set(obj.hFig, 'WindowButtonMotionFcn', @obj.pointerReporter)


            obj.button_previewScan=uicontrol(...
                'Parent', obj.statusPanel, ...
                'Position', [690, 2, 90, 32], ...
                'Units','Pixels',...
                'ForegroundColor','k', ...
                'FontWeight', 'bold', ...
                'String', 'Preview Scan', ...
                'BackgroundColor', [1,0.75,0.25], ...
                'Callback', @obj.startPreviewScan);


            % Add buttons for zooming in and out and drawing the boundary box
            obj.button_zoomIn = uicontrol(...
                'Parent', obj.statusPanel, ...
                'Position', [642 19 15 15], ...
                'Units', 'Pixels', ...
                'String', '+', ...
                'Tag', 'zoomin', ... 
                'ToolTip', 'Zoom in', ...
                'Callback', @obj.imageZoomHandler);

            obj.button_zoomOut = uicontrol(...
                'Parent', obj.statusPanel, ...
                'Position', [642 2 15 15], ...
                'Units', 'Pixels', ...
                'String', '-', ...
                'Tag', 'zoomout', ... 
                'ToolTip', 'Zoom out', ...
                'Callback', @obj.imageZoomHandler);


            obj.button_zoomNative = uicontrol(...
                'Parent', obj.statusPanel, ...
                'Position', [660 2 15 15], ...
                'Units', 'Pixels', ...
                'String', '0', ...
                'Tag', 'zerozoom', ...
                'ToolTip', 'Reset zoom',... 
                'Callback', @obj.imageZoomHandler);

            obj.button_drawBox = uicontrol(...
                'Parent', obj.statusPanel, ...
                'Position', [660 19 15 15], ...
                'Units', 'Pixels', ...
                'String', 'B', ...
                'ToolTip', 'Select area to image', ...
                'Callback', @obj.areaSelector);

            % Add checkboxes for toggling disabling the laser at the end of acquisition and for 
            % slicing the last section at the end of acquisition. 
            obj.checkBoxLaserOff = uicontrol(...
                'Parent', obj.statusPanel, ...
                'Units', 'Pixels', ...
                'String', 'Laser off', ...
                'Position', [505, 18, 70, 17], ...
                'Style','check', ... 
                'ToolTip', 'Turn off laser when acquisition finishes', ...
                'ForegroundColor', 'w', ...
                'BackgroundColor', [1,1,1]*0.075, ...
                'Value', ~obj.model.leaveLaserOn, ...
                'Callback', @obj.updateLeaveLaserOn);

            obj.checkBoxCutLast = uicontrol(...
                'Parent', obj.statusPanel, ...
                'Units', 'Pixels', ...
                'Style','check', ... 
                'String', 'Slice last', ...
                'Position', [505, 2, 70, 17], ...
                'ToolTip', 'Slice the final imaged section off the block', ...
                'ForegroundColor', 'w', ...
                'BackgroundColor', [1,1,1]*0.075, ...
                'Value', obj.model.sliceLastSection, ...
                'Callback', @obj.updateSliceLastSection);


            %Add some listeners to monitor properties on the scanner component
            obj.listeners{1}=addlistener(obj.model, 'currentTilePosition', 'PostSet', @obj.placeNewTilesInPreviewData);

            obj.listeners{end+1}=addlistener(obj.model.scanner, 'acquisitionPaused', 'PostSet', @obj.updatePauseButtonState);
            obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.updatePauseButtonState);
            obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.updatePauseButtonState);

            obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.updateBakeButtonState);
            obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.updateBakeButtonState);

            obj.listeners{end+1}=addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.disable_ZoomElementsDuringAcq);
            obj.listeners{end+1}=addlistener(obj.model, 'abortAfterSectionComplete', 'PostSet', @obj.updateBakeButtonState);


            % The channels that can be displayed are updated with these two listeners
            obj.listeners{end+1}=addlistener(obj.model.scanner,'channelsToSave', 'PostSet', @obj.updateChannelsPopup);
            obj.listeners{end+1}=addlistener(obj.model.scanner,'scanSettingsChanged', 'PostSet', @obj.updateChannelsPopup);

            obj.listeners{end+1}=addlistener(obj.model.scanner, 'channelLookUpTablesChanged', 'PostSet', @obj.updateImageLUT);
            obj.listeners{end+1}=addlistener(obj.model.scanner, 'isScannerAcquiring', 'PostSet', @obj.updateBakeButtonState);
            obj.listeners{end+1}=addlistener(obj.model, 'isSlicing', 'PostSet', @obj.indicateCutting);

            obj.listeners{end+1}=addlistener(obj.model.recipe, 'mosaic', 'PostSet', @obj.populateDepthPopup);

            % Update checkboxes
            obj.listeners{end+1}=addlistener(obj.model, 'leaveLaserOn', 'PostSet', @(~,~) set(obj.checkBoxLaserOff,'Value',~obj.model.leaveLaserOn) );
            obj.listeners{end+1}=addlistener(obj.model, 'sliceLastSection', 'PostSet', @(~,~) set(obj.checkBoxCutLast,'Value',obj.model.sliceLastSection) );

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


    methods(Hidden)
        function updateGUIonResize(obj,~,~)
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


        function setUpImageAxes(obj)
            % Add a blank images to the image axes
            blankImage = squeeze(obj.previewImageData(:,:,obj.depthToShow,obj.chanToShow));
            if obj.rotateSectionImage90degrees
                blankImage = rot90(blankImage);
            end

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
            set(obj.hFig,'Colormap', gray(256))
        end %setUpImageAxes


        function initialisePreviewImageData(obj,tp)
            % Calculate where the tiles will go in the preview image the create the image
            % if the tile pattern (output of the recipe tilePattern method) is not supplied
            % then it is obtained here. 

            if nargin<2
                tp=obj.model.recipe.tilePattern; %Stage positions in mm (x,y)
            end

            if isempty(tp)
                fprintf('ERROR: no tile position data. initialisePreviewImageData can not build empty image\n')
                return
            end
            tp(:,1) = tp(:,1) - tp(1,1);
            tp(:,2) = tp(:,2) - tp(1,2);


            tp=abs(tp);
            tp=ceil(tp/obj.model.downsampleTileMMperPixel);
            obj.previewTilePositions=tp;

            ovLap = obj.model.recipe.mosaic.overlapProportion+1;

            % The size of the preview image
            stepSizes = max(abs(diff(tp)));
            %              imsize + tile size including overlap
            imCols = range(tp(:,1)) + round(stepSizes(1) * ovLap);
            imRows = range(tp(:,2)) + round(stepSizes(2) * ovLap);


            obj.previewImageData = ones([imRows,imCols, ...
                obj.model.recipe.mosaic.numOpticalPlanes, ...
                obj.model.scanner.maxChannelsAvailable],'int16') * -2E15;

            obj.model.downSampledTileBuffer(:)=0;

            if ~isempty(obj.sectionImage)
                obj.sectionImage.CData(:)=0;
            end

            % Log the current front/left position from the recipe
            obj.frontLeftWhenPreviewWasTaken.X = obj.model.recipe.FrontLeft.X;
            obj.frontLeftWhenPreviewWasTaken.Y = obj.model.recipe.FrontLeft.Y;

            fprintf('Initialised a preview image of %d columns by %d rows\n', imCols, imRows)
        end %initialisePreviewImageData


        function indicateCutting(obj,~,~)
            % Changes GUI elements accordingly during cutting
            if obj.verbose, fprintf('In acquisition_view.indicateCutting callback\n'), end
            if obj.model.isSlicing
                obj.statusText.String=' ** CUTTING SAMPLE **';
                % TODO: I think these don't work. bake/stop isn't affected and pause doesn't come back. 
                %obj.button_BakeStop.Enable='off';
                %obj.button_Pause.Enable='off';

                %If we are acquiring data, save the current preview stack to disk
                if exist(obj.model.logPreviewImageDataToDir,'dir') && obj.model.acquisitionInProgress
                    tDate = datestr(now,'YYYY_MM_DD');
                    fname=sprintf('%s_section_%d_%s.mat', ...
                                    obj.model.recipe.sample.ID, ...
                                    obj.model.currentSectionNumber, ...
                                    tDate);
                    save(fname,obj.previewImageData)
                end

            else
                obj.updateStatusText
                %obj.updateBakeButtonState  % TODO: why is this here?
                %obj.updatePauseButtonState % TODO: why is this here?
            end
        end %indicateCutting


        function updateStatusText(obj,~,~)
            % Update the text in the top left of the acquisition view
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


        function placeNewTilesInPreviewData(obj,~,~)
            % When new tiles are acquired they are placed into the correct location in
            % the obj.previewImageData array. This is run when the tile position increments
            % So it only runs once per X/Y position. 

            if obj.verbose, fprintf('In acquisition_view.placeNewTilesInPreviewData callback\n'), end

            %TODO: temporarily do not build preview if ribbon-scanning
            if strcmp(obj.model.recipe.mosaic.scanmode,'ribbon')
                return
            end

            obj.updateStatusText
            if obj.model.processLastFrames==false
                return
            end

            %If the current tile position is 1 that means it was reset from its final value at the end of the last
            %section to 1 by BT.runTileScan. So that indicates the start of a section. If so, we wipe all the 
            %buffer data so we get a blank image
            if obj.model.currentTilePosition==1
                obj.initialisePreviewImageData;
            end

            if obj.model.lastTilePos.X>0 && obj.model.lastTilePos.Y>0
                % Caution changing these lines: tiles may be rectangular
                %Where to place the tile
                y = (1:size(obj.model.downSampledTileBuffer,1)) + obj.previewTilePositions(obj.model.lastTileIndex,2);
                x = (1:size(obj.model.downSampledTileBuffer,2)) + obj.previewTilePositions(obj.model.lastTileIndex,1);

                % NOTE: do not write to obj.model.downSampled tiles. Only the scanner should write to this.

                %Place the tiles into the full image grid so it can be plotted (there is a listener on this property to update the plot)
                obj.previewImageData(y,x,:,:) = obj.model.downSampledTileBuffer;

                %Only update the section image every so often to avoid slowing down the acquisition
                n=obj.model.currentTilePosition;
                if n==1 || mod(n,10)==0 || n==length(obj.model.positionArray)
                    obj.updateSectionImage
                end

                obj.model.downSampledTileBuffer(:) = 0; %wipe the buffer 
            end % obj.model.lastTilePos.X>0 && obj.model.lastTilePos.Y>0

        end %placeNewTilesInPreviewData

        function updateSectionImage(obj,~,~)
            % This callback function updates when the listener on obj.previewImageData fires or if the user 
            % updates the popup boxes for depth or channel
            if obj.verbose, fprintf('In acquisition_view.updateSectionImage callback\n'), end


            %TODO: Temporarily do not update section imaging if ribbon scanning
            if strcmp(obj.model.recipe.mosaic.scanmode,'ribbon')
                return
            end

            if ~obj.doSectionImageUpdate
                return
            end



            %Raise a console warning if it looks like the image has grown in size
            %TODO: this check can be removed eventually, once we're sure this does not happen ever.
            if numel(obj.sectionImage.CData) < numel(squeeze(obj.previewImageData(:,:,obj.depthToShow, obj.chanToShow)))
                fprintf('The preview image data in the acquisition GUI grew in size from %d x %d to %d x %d\n', ...
                    size(obj.sectionImage.CData,1), size(obj.sectionImage.CData,2), ...
                    size(obj.previewImageData,1), size(obj.previewImageData,2) )
            end

            if obj.rotateSectionImage90degrees
                obj.sectionImage.CData = rot90(squeeze(obj.previewImageData(:,:,obj.depthToShow, obj.chanToShow)));
            else
                obj.sectionImage.CData = squeeze(obj.previewImageData(:,:,obj.depthToShow, obj.chanToShow));
            end


        end %updateSectionImage


        % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
        function bake_callback(obj,~,~)
            % Run when the bake button is pressed
            if obj.verbose, fprintf('In acquisition_view.bake callback\n'), end

            obj.updateStatusText
            %Check whether it's safe to begin
            [acqPossible, msg]=obj.model.checkIfAcquisitionIsPossible;
            if ~acqPossible
                if ~isempty(msg)
                    warndlg(msg,'');
                end
               return
            end

            % Allow the user to confirm they want to bake
            ohYes='Yes!';
            noWay= 'No way';
            choice = questdlg('Are you sure you want to Bake this sample?', '', ohYes, noWay, noWay);

            switch choice
                case ohYes
                    % pass
                case noWay
                    return
                otherwise
                    return
            end 


            % Update the preview image in case the recipe has altered since the GUI was opened or
            % since the preview was last taken.
            obj.initialisePreviewImageData;
            obj.setUpImageAxes;


            % Force update of the depths and channels because for some reason they 
            % sometimes do not update when the recipe changes. 
            obj.populateDepthPopup
            obj.updateChannelsPopup

            obj.chooseChanToDisplay %By default display the channel shown in ScanImage

            set(obj.button_Pause, obj.buttonSettings_Pause.enabled{:})
            obj.button_BakeStop.Enable='off'; %This gets re-enabled when the scanner starts imaging

            obj.updateImageLUT;
            obj.model.leaveLaserOn=false; % TODO: For now always set the laser to switch off when starting [17/08/2017]
            try
                obj.model.bake;
            catch ME
                disp('BAKE FAILED IN acquisition_view. CAUGHT_ERROR')
                disp(ME.message)
                obj.button_BakeStop.Enable='on'; 
                return
            end
            
            if obj.checkBoxLaserOff.Value
                % If the laser was slated to turn off then we also close
                % the acquisition GUI. This is because a lot of silly bugs
                % seem to crop up after an acquisition but they go away if
                % the user closes and re-opens the window.
                obj.delete
            end

        end %bake_callback


        function stop_callback(obj,~,~)
            % Run when the stop button is pressed
            % If the system has not been told to stop after the next section, pressing the 
            % button again will stop this from happening. Otherwise we proceed with the 
            % question dialog. Also see SIBT.tileScanAbortedInScanImage

            if obj.verbose, fprintf('In acquisition_view.stop callback\n'), end

            if obj.model.abortAfterSectionComplete
                obj.model.abortAfterSectionComplete=false;
                return
            end

            stopNow='Yes: stop NOW';

            stopAfterSection='Yes: stop after this section';
            noWay= 'No way';
            choice = questdlg('Are you sure you want to stop acquisition?', '', stopNow, stopAfterSection, noWay, noWay);

            switch choice
                case stopNow

                    %If the acquisition is paused we un-pause then stop. No need to check if it's paused.
                    obj.model.scanner.resumeAcquisition;

                    %TODO: these three lines also appear in BT.bake
                    obj.model.leaveLaserOn=true; %TODO: we could have a GUI come up that allows the user to choose if they want this happen.
                    obj.model.abortAcqNow=true; %Otherwise in ribbon scanning it moved to the next optical plane
                    obj.model.scanner.abortScanning;
                    obj.model.scanner.disarmScanner;
                    obj.model.detachLogObject;
                    set(obj.button_Pause, obj.buttonSettings_Pause.disabled{:})

                case stopAfterSection
                    %If the acquisition is paused we resume it then it will go on to stop.
                    obj.model.scanner.resumeAcquisition;
                    obj.model.abortAfterSectionComplete=true;

                otherwise
                    %Nothing happens
            end 
        end %stop_callback


        function pause_callback(obj,~,~)
            % Run when the pause button is pressed
            % Pauses or resumes the acquisition according to the state of the observable property in scanner.acquisitionPaused
            % This will not pause cutting. It will only pause the system when it's acquiring data. If you press this during
            % cutting the acquisition of the next section will not begin until pause is disabled. 
            if ~obj.model.acquisitionInProgress
                obj.updatePauseButtonState;
                return
            end

            if obj.model.scanner.acquisitionPaused
                %If acquisition is paused then we resume it
                obj.model.scanner.resumeAcquisition;
            elseif ~obj.model.scanner.acquisitionPaused
                %If acquisition is running then we pause it
                obj.model.scanner.pauseAcquisition;
            end

        end %pause_callback

        function startPreviewScan(obj,~,~)
            %Starts a rapd, one depth, preview scan. 

            %TODO: The warning dialog in case of failure to scan is created in BT.takeRapidPreview
            %       Ideally it should be here, to matach what happens elsewhere, but this is not 
            %       possible right now because we have to transiently change the sample ID to have
            %       the acquisition proceed if data already exist in the sample directory. Once this
            %       is fixed somehow the dialog creation will come here. 

            if obj.verbose, fprintf('In acquisition_view.pause callback\n'), end

            %Disable depth selector since we have just one depth
            depthEnableState=obj.depthSelectPopup.Enable;
            obj.depthSelectPopup.Enable='off';
            obj.button_BakeStop.Enable='off'; %This gets re-enabled when the scanner starts imaging

            obj.chooseChanToDisplay %By default display the channel shown in ScanImage


            % Update the preview image in case the recipe has altered since the GUI was opened or
            % since the preview was last taken.
            obj.initialisePreviewImageData;
            obj.setUpImageAxes;

            if size(obj.previewImageData,3)>1
                %A bit nasty but temporarily wipe the higher depths (they'll be re-made later)
                obj.previewImageData(:,:,2:end,:)=[];
            end

            obj.updateImageLUT;
            try
                obj.model.takeRapidPreview
            catch 
            end

            %Ensure the bakeStop button is enabled if BT.takeRapidPreview failed to run
            obj.button_BakeStop.Enable='on'; 
            obj.depthSelectPopup.Enable=depthEnableState; %return to original state
        end %startPreviewScan

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


        function updateBakeButtonState(obj,~,~)
            if obj.verbose, fprintf('In acquisition_view.updateBakeButtonState callback\n'), end

            if obj.model.acquisitionInProgress && ~obj.model.scanner.isAcquiring
                % This disables the button during the dead-time between asking for an acquisition
                % and it actually beginning
                obj.button_BakeStop.Enable='off';
            else
                obj.button_BakeStop.Enable='on';
            end

            if ~obj.model.acquisitionInProgress 
                %If there is no acquisition we put buttons into a state where one can be started
                set(obj.button_BakeStop, obj.buttonSettings_BakeStop.bake{:})
                obj.button_previewScan.Enable='on';

            elseif obj.model.acquisitionInProgress && ~obj.model.abortAfterSectionComplete && ~obj.model.isSlicing
                %If there is an acquisition in progress and we're not waiting to abort after this section
                %then it's allowed to have a stop option.
                set(obj.button_BakeStop, obj.buttonSettings_BakeStop.stop{:})
                obj.button_previewScan.Enable='off';
                obj.button_BakeStop.Enable='on';

            elseif obj.model.acquisitionInProgress && ~obj.model.abortAfterSectionComplete && obj.model.isSlicing
                %If there is an acquisition in progress and we're not waiting to abort after this section
                %then it's allowed to have a stop option.
                set(obj.button_BakeStop, obj.buttonSettings_BakeStop.stop{:})
                obj.button_previewScan.Enable='off';
                obj.button_BakeStop.Enable='off';

            elseif obj.model.acquisitionInProgress && obj.model.abortAfterSectionComplete
                %If there is an acquisition in progress and we *are* waiting to abort after this section
                %then we are give the option to cancel stop.
                set(obj.button_BakeStop, obj.buttonSettings_BakeStop.cancelStop{:})
                obj.button_previewScan.Enable='off';
            end

        end %updateBakeButtonState


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
                activeChannels = obj.model.scanner.channelsToDisplay;
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


        function populateDepthPopup(obj,~,~)
            % BakingTray.gui.acquisition_view.populateDepthPopup
            %
            % This callback runs when the user changes the number of depths to be 
            % acquired. It is also called in the constructor. It adds the correct 
            % number of optical planes (depths) to the depths popup so the user 
            % can select which plane they want to view. 

            opticalPlanes_str = {};
            for ii=1:obj.model.recipe.mosaic.numOpticalPlanes
                opticalPlanes_str{end+1} = sprintf('Depth %d',ii);
            end
            if length(opticalPlanes_str)>1 && ~isempty(obj.model.scanner.channelsToDisplay)
                obj.depthSelectPopup.String = opticalPlanes_str;
                obj.depthSelectPopup.Enable='on';
            else
                obj.depthSelectPopup.String = 'NONE';
                obj.depthSelectPopup.Enable='off';
            end
        end %populateDepthPopup

        function setDepthToView(obj,~,~)
            % BakingTray.gui.acquisition_view.setDepthToView
            %
            % This callback runs when the user interacts with the depth popup.
            % The callback sets which depth will be displayed

            if obj.verbose, fprintf('In acquisition_view.setDepthToView callback\n'), end

            if isempty(obj.model.scanner.channelsToDisplay)
                %Don't do anything if no channels are being viewed
                return
            end
            if strcmp(obj.depthSelectPopup.Enable,'off')
                return
            end
            thisSelection = obj.depthSelectPopup.String{obj.depthSelectPopup.Value};
            thisDepthIndex = str2double(regexprep(thisSelection,'\w+ ',''));

            if thisDepthIndex>size(obj.previewImageData,3)
                %If the selected value is out of bounds default to the first depth
                thisDepthIndex=1;
                obj.depthSelectPopup.Value=1;
            end

            obj.depthToShow = thisDepthIndex;
            obj.updateSectionImage;
        end %setDepthToView

        function setChannelToView(obj,~,~)
            if obj.verbose, fprintf('In acquisition_view.setChannelToView callback\n'), end

            % This callback runs when the user ineracts with the channel popup.
            % The callback sets which channel will be displayed
            if isempty(obj.model.scanner.channelsToDisplay)
                %Don't do anything if no channels are being viewed
                return
            end
            thisSelection = obj.channelSelectPopup.String{obj.channelSelectPopup.Value};
            thisChannelIndex = str2double(regexprep(thisSelection,'\w+ ',''));
            if isempty(thisChannelIndex)
                return
            end
            obj.chanToShow=thisChannelIndex;
            obj.updateSectionImage;
            obj.updateImageLUT;
        end %setDepthToView

        function chooseChanToDisplay(obj)
            % Choose a channel to display as a default: For now just the first channel

            if obj.verbose, fprintf('In acquisition_view.chooseChanToDisplay callback\n'), end

            channelsBeingAcquired = obj.model.scanner.channelsToAcquire;
            channelsScannerDisplays = obj.model.scanner.channelsToDisplay;

            if isempty(channelsScannerDisplays)
                % Then we can't display anything
                return
            end

            %TODO: we can choose this more cleverly in future
            obj.channelSelectPopup.Value=1;

            obj.setChannelToView
        end %chooseChanToDisplay

        function pointerReporter(obj,~,~)
            % Runs when the mouse is moved over the axis to report its position in stage coordinates. 
            % This is printed as text to the top left of the plot. The callback does not run if an
            % acquisition is in progress or if the plotted image contains only zeros.

            if obj.verbose, fprintf('In acquisition_view.pointerReporter callback\n'), end

            % Report stage position to screen. The reported position is the 
            % top/left tile position.
            if obj.model.acquisitionInProgress || all(obj.sectionImage.CData(:)==0)
                return
            end

            pos=get(obj.imageAxes, 'CurrentPoint');
            xAxisCoord=pos(1,1);
            yAxisCoord=pos(1,2);

            stagePos = obj.convertImageCoordsToStagePosition([xAxisCoord,yAxisCoord]);
            obj.statusText.String = sprintf('Stage Coordinates:\nX=%0.2f mm Y=%0.2f mm', stagePos);

        end % pointerReporter

        function areaSelector(obj,~,~)

            h = imrect(obj.imageAxes);
            rect_pos = wait(h);
            delete(h)
            [rectBottomLeft,MMpix] = obj.convertImageCoordsToStagePosition(rect_pos(1:2));

            frontPos = rectBottomLeft(2);
            leftPos  = rectBottomLeft(1) + MMpix*rect_pos(4);

            extentAlongX = round(rect_pos(4)*MMpix,2);
            extentAlongY = round(rect_pos(3)*MMpix,2);
            detailedMessage=false;
            if detailedMessage
                msg = sprintf(['Proceed with the following changes?\n', ...
                    'Set the front/left position changes:\n', ...
                     'X= %0.2f mm -> %0.2f\nY= %0.2f mm -> %0.2f mm\n', ...
                    'The imaging area will change from from:\n', ...
                    'X= %0.2f mm -> %0.2f mm\nY= %0.2f mm -> %0.2f mm'], ...
                    obj.model.recipe.FrontLeft.X, leftPos, ...
                    obj.model.recipe.FrontLeft.Y, frontPos, ...
                    obj.model.recipe.mosaic.sampleSize.X, extentAlongX, ...
                    obj.model.recipe.mosaic.sampleSize.Y, extentAlongY);
            else
                msg = 'Apply new selection box?';
            end

            A=questdlg(msg);

            if strcmpi(A,'yes')
                obj.model.recipe.FrontLeft.X = leftPos;
                obj.model.recipe.FrontLeft.Y = frontPos;
                obj.model.recipe.mosaic.sampleSize.X = extentAlongX;
                obj.model.recipe.mosaic.sampleSize.Y = extentAlongY;
                fprintf('\nRECIPE UPDATED\n')
            end

        end % areaSelector

        function [stagePos,mmPerPixelDownSampled] = convertImageCoordsToStagePosition(obj, coords)
            % Convert a position in the preview image to a stage position in mm
            %
            % Inputs
            % coords is [x coord, y coord]
            % 
            % Outputs
            % stagePos is [x stage pos, y stage pos]
            % xMMPix - number of mm per pixel in X
            % yMMPix - number of mm per pixel in Y
            %
            % Note that the Y axis of the plot is motion of the X stage.

            xAxisCoord = coords(1);
            yAxisCoord = coords(2);

            %Determine the size of the image in mm
            mmPerPixelDownSampled = (obj.model.recipe.ScannerSettings.pixelsPerLine / obj.model.downsamplePixPerLine) * ...
                 obj.model.recipe.ScannerSettings.micronsPerPixel_cols * 1E-3;

            % How the figure is set up:
            % * The Y axis of the image (rows) corresponds to motion of the X stage. 
            %   X stage values go negative as we move up the axis (where axis values become more postive)
            % 
            % * The X axis of the image (columns) corresponds to motion of the Y stage
            %   Both Y stage values and X axis values become more positive as we move to the right.
            %
            % * The front/left position is at the top left of the figure

            % Note that the figure x axis is the y stage axis, hence the confusing mixing of x and y below

            % Get the X stage value for y=0 (right most position) and we'll reference off that
            frontRightX = obj.frontLeftWhenPreviewWasTaken.X - size(obj.previewImageData,2)*mmPerPixelDownSampled;

            xPosInMM = frontRightX + yAxisCoord*mmPerPixelDownSampled;
            yPosInMM = obj.frontLeftWhenPreviewWasTaken.Y- xAxisCoord*mmPerPixelDownSampled;

            stagePos = [xPosInMM,yPosInMM];
        end % convertImageCoordsToStagePosition


        function imageZoomHandler(obj,src,~)
            % This callback function is run when the user presses the zoom out, in, or zero zoom
            % buttons in the control bar at the top of the GUI.

            zoomProp=0.15; % How much to zoom in and out each time the button is pressed

            switch src.Tag
            case 'zoomin'
                % Determine first if zooming in is possible
                YLim =[obj.imageAxes.YLim(1) + size(obj.previewImageData,2)*zoomProp, ... 
                    obj.imageAxes.YLim(2) - size(obj.previewImageData,2)*zoomProp];

                XLim = [obj.imageAxes.XLim(1) + size(obj.previewImageData,1)*zoomProp, ...
                    obj.imageAxes.XLim(2) - size(obj.previewImageData,1)*zoomProp];

                if diff(YLim)<1 || diff(XLim)<1
                    % Then we've tried to zoom in too far, disable the zoom in button
                    obj.button_zoomIn.Enable='off';
                    return
                end
                obj.imageAxes.YLim(1) = obj.imageAxes.YLim(1) + size(obj.previewImageData,2)*zoomProp;
                obj.imageAxes.YLim(2) = obj.imageAxes.YLim(2) - size(obj.previewImageData,2)*zoomProp;
                obj.imageAxes.XLim(1) = obj.imageAxes.XLim(1) + size(obj.previewImageData,1)*zoomProp;
                obj.imageAxes.XLim(2) = obj.imageAxes.XLim(2) - size(obj.previewImageData,1)*zoomProp;
            case 'zoomout'
                obj.button_zoomIn.Enable='on'; %In case it was previously disabled
                obj.imageAxes.YLim(1) = obj.imageAxes.YLim(1) - size(obj.previewImageData,2)*zoomProp;
                obj.imageAxes.YLim(2) = obj.imageAxes.YLim(2) + size(obj.previewImageData,2)*zoomProp;
                obj.imageAxes.XLim(1) = obj.imageAxes.XLim(1) - size(obj.previewImageData,1)*zoomProp;
                obj.imageAxes.XLim(2) = obj.imageAxes.XLim(2) + size(obj.previewImageData,1)*zoomProp;
            case 'zerozoom'
                obj.button_zoomIn.Enable='on'; %In case it was previously disabled
                obj.imageAxes.YLim = [0,size(obj.previewImageData,2)];
                obj.imageAxes.XLim = [0,size(obj.previewImageData,1)];
            otherwise 
                fprintf('bakingtray.gui.acquisition_view.imageZoomHandler encounters unknown source tag: "%s"\n',src.Tag)
            end

        end

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

    end %close hidden methods


end
