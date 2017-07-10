classdef view < handle


    properties
        hFig
        model %The BT model object goes here

        %Buttons attach to these properties
        button_chooseDir
        button_laser
        button_recipe
        button_prepare
        button_start

        view_laser      %The laser GUI object is stored here
        view_prepare    %The prepare GUI object is stored here
        view_acquire    %The acquisition GUI object is stored here

        %Text display boxes
        text_sampleDir
        text_recipeFname

        text_status

        recipeTextLabels=struct %annotation text boxes with labels of recipe fields
        recipeEntryBoxes=struct %the user enters recipe values here

        %Top menu
        menu
    end



    properties(Hidden)
        timerUpdateInterval=0.33 %Any timers will update the GUI every so many seconds
        fSize=12;
        listeners={}

        %These properties are used to build and populate the recipe fields
        %The property is split by "||" to handle nesting
        recipePropertyNames  = {'sample||ID', 'sample||objectiveName', 'mosaic||numSections', ...
                    'mosaic||numOpticalPlanes', 'mosaic||sectionStartNum', ...
                    'mosaic||overlapProportion', 'mosaic||sampleSize', ...
                    'mosaic||cuttingSpeed','mosaic||cutSize', 'mosaic||sliceThickness', ...
                    }

        recipeFieldLabels = {'Sample ID', 'Objective Name', 'Num. Sections', ...
                    'Num. Optical Planes', 'Section Start Num.', ...
                    'Overlap Prop.', 'Sample Size (mm)', ...
                    'Cut Speed (mm/s)', 'Cut Size (mm)', 'Slice Thickness (mm)', ...
                    }

        recipeToolTips = {sprintf('String defining the sample ID.\nSpaces will be replaced with underscores.\nNames with leading digits will have a string appended.'), ...
                    'The name of the objective.\nCurrently only used as a note.', ...
                    'Number of sections to cut and image.', ...
                    'The numeric ID of the first section', ...
                    'The number of optical planes within a section', ...
                    'Proportion of overlap between adjacent tiles', ...
                    'Size of the sample in mm', ...
                    'Cutting speed in mm/s', ...
                    'How far to cut from the cutting start point', ...
                    'Thickness of each slice in mm', ...
                    }
        %Panels
        basicSetupPanel %house dir and recipe buttons 
        hardwarePanel %houses buttons that will do stuff to hardware
        statusPanel  %For now this will house a general purpose display box - just dump a big text string into it 
        recipePanel %recipe editing goes here

        suppressToolTips=true



    end



    methods

        function obj = view(hBT)

            if nargin>0
                obj.model = hBT;
            else
                fprintf('Can''t build BakingTray.gui.view please supply BT model as input argument\n');
                return
            end

            if ispc
                obj.fSize=9; 
            end

            obj.hFig = BakingTray.gui.newGenericGUIFigureWindow('BakingTray_View');

            %Resize the figure window
            pos=get(obj.hFig, 'Position');
            pos(3:4)=[300,400];
            set(obj.hFig, ...
                'Position',pos, ... 
                'units','pixels', ...
                'DockControls','off', ...
                'Name', 'BakingTray')

            % Closing the figure closes BakingTray
            set(obj.hFig,'CloseRequestFcn', @obj.closeBakingTray)

            %----------------------------------------------------------------------------------------
            %Menu
            obj.menu.main = uimenu(obj.hFig,'Label','Tools');
            obj.menu.scanner = uimenu(obj.hFig,'Label','Scanner');
            obj.menu.api = uimenu(obj.menu.main,'Label','Generate API handles','Callback',@obj.copyAPItoBaseWorkSpace);
            obj.menu.api = uimenu(obj.menu.main,'Label','Save recipe','Callback',@obj.saveRecipeToDisk);

            %If the user runs ScanImage, prompt to connect to ScanImage
            settings=BakingTray.settings.readComponentSettings;
            if strcmp(settings.scanner.type,'SIBT')
                obj.menu.connectScanImage = uimenu(obj.menu.scanner,'Label','Connect ScanImage','Callback',@obj.connectScanImage);
            end
            obj.menu.armScanner = uimenu(obj.menu.scanner,'Label','Arm Scanner','Callback', @(~,~) obj.model.scanner.armScanner);
            obj.menu.disarmScanner = uimenu(obj.menu.scanner,'Label','Disarm Scanner','Callback', @(~,~) obj.model.scanner.disarmScanner);

            obj.menu.about = uimenu(obj.menu.main,'Label','About','Callback',@obj.about);
            obj.menu.quit = uimenu(obj.menu.main,'Label','Quit','Callback',@obj.closeBakingTray);


            %----------------------------------------------------------------------------------------
            %Basic status panel - directory selection and recipe loading
            commonButtonSettings={'Units', 'pixels', 'FontSize', obj.fSize, 'FontWeight', 'bold'};

            obj.basicSetupPanel = BakingTray.gui.newGenericGUIPanel([3.5, 345, 295, 55],obj.hFig);
            obj.button_chooseDir = uicontrol(...
                commonButtonSettings{:}, ...
                'Parent', obj.basicSetupPanel, ...
                'Position', [5, 28, 40, 20], ...
                'Callback',@obj.changeDir, ...
                'String', 'Dir');
            if ~obj.suppressToolTips
                obj.button_chooseDir.TooltipString='Choose sample directory';
            end

            if ~isempty(obj.model.sampleSavePath)
                cwd=strrep(obj.model.sampleSavePath,'\','\\');
            else 
                cwd='';
            end
            obj.text_sampleDir = annotation(...
                 obj.basicSetupPanel, 'textbox', ...
                'Units', 'pixels', ...
                'Position', [50,28,240,19] , ...
                'EdgeColor', [1,1,1]*0.5, ...
                'Color', 'w', ...
                'VerticalAlignment', 'middle',...
                'FontSize', obj.fSize, ...
                'FitBoxToText','off', ...
                'String', strrep(cwd,'_','\_'));

            obj.button_recipe = uicontrol(...
                commonButtonSettings{:}, ...
                'Parent', obj.basicSetupPanel, ...
                'Position', [5,4, 55, 20], ...
                'String', 'Recipe', ...
                'Callback', @obj.loadRecipe);
            if ~obj.suppressToolTips
                obj.button_recipe.TooltipString='Load recipe';
            end


            obj.text_recipeFname = annotation(...
                 obj.basicSetupPanel, 'textbox', ...
                'Units', 'pixels', ...
                'Position', [65,4,225,19] , ...
                'EdgeColor', [1,1,1]*0.5, ...
                'Color', 'w', ...
                'VerticalAlignment', 'middle',...
                'FontSize', obj.fSize, ...
                'FitBoxToText','off', ...
                'String', '');
            %TODO: add a listener to this updates when the user loads a new recipe
            obj.updateRecipeFname 


            %Buttons for interfacing with hardware
            obj.hardwarePanel = BakingTray.gui.newGenericGUIPanel([3.5, 295, 295, 45],obj.hFig);

            obj.button_laser = uicontrol(...
                commonButtonSettings{:}, ...
                'Parent', obj.hardwarePanel, ...
                'Position', [10,12.5, 50, 20], ...
                'Callback',@obj.startLaserGUI, ...
                'String', 'Laser');
            if ~obj.suppressToolTips
                obj.button_laser.TooltipString='Start laser GUI';
            end
            %Disable the laser button if no laser is connected
            if ~obj.model.isLaserConnected
                obj.button_laser.Enable='off';
            end

            obj.button_prepare = uicontrol(...
                commonButtonSettings{:}, ...
                'Parent', obj.hardwarePanel, ...
                'Position', [65,12.5, 110, 20], ...
                'String', 'Prepare Sample', ...
                'Callback',@obj.startPrepareGUI);
            if ~obj.suppressToolTips
                obj.button_prepare.TooltipString='Cut and prepare sample for imaging';
            end

            obj.button_start = uicontrol(...
                commonButtonSettings{:}, ...
                'Parent', obj.hardwarePanel, ...
                'Position', [180,12.5, 55, 20], ...
                'Callback',@obj.START, ...
                'String', 'Start', ....
                'ForegroundColor','k');
            if ~obj.suppressToolTips
                obj.button_start.TooltipString='Begin acquisition';
            end

            %Status panel
            obj.statusPanel = BakingTray.gui.newGenericGUIPanel([3.5, 200, 295, 90],obj.hFig);
            obj.text_status = annotation(...
                 obj.statusPanel, 'textbox', ...
                'Units', 'pixels', ...
                'Position', [2,2,obj.statusPanel.Position(3:4)-4], ...
                'EdgeColor', 'none', ...
                'Color', 'w', ...
                'FontSize', obj.fSize, ...
                'FitBoxToText','off', ...
                'String', '');

            obj.updateStatusText

            %Recipe panel
            obj.recipePanel = BakingTray.gui.newGenericGUIPanel([3.5, 5, 295, 190],obj.hFig);

            %To have the order the way I'd like (sample at the top)
            obj.recipeFieldLabels=fliplr(obj.recipeFieldLabels);
            obj.recipePropertyNames=fliplr(obj.recipePropertyNames);
            obj.recipeToolTips=fliplr(obj.recipeToolTips);

            commonRecipeTextEditSettings={'Parent', obj.recipePanel, ...
                        'Style','edit', 'Units', 'pixels', 'FontSize', obj.fSize, ...
                        'HorizontalAlignment', 'Left', ...
                        'Callback',@obj.updateRecipePropertyInRecipeClass};


            for ii=length(obj.recipePropertyNames):-1:1 %So the tab focus moves down the window not up it
                thisProp = strsplit(obj.recipePropertyNames{ii},'||');

                %Add a text label
                obj.recipeTextLabels.(thisProp{1}).(thisProp{2}) = obj.makeRecipeLabel([0,18*(ii-1)+5,140,18], obj.recipeFieldLabels{ii});
                obj.recipeTextLabels.(thisProp{1}).(thisProp{2}).VerticalAlignment='middle';
                %Add a text entry box
                if ~strcmp(thisProp{2},'sampleSize') %Because sample size is a structure that describes both X and Y
                    %Numeric boxes can be smaller than text boxes, so figure out which is which and set the length:
                    if ~isempty(regexp(obj.recipeFieldLabels{ii},'\(mm', 'once')) || ...
                        ~isempty(regexp(obj.recipeFieldLabels{ii},'Prop\.', 'once')) || ...
                        ~isempty(regexp(obj.recipeFieldLabels{ii},'Num\.', 'once')) 
                        textEditWidth=45;
                    else
                        textEditWidth=140;
                    end
                    obj.recipeEntryBoxes.(thisProp{1}).(thisProp{2}) = ...
                    uicontrol(commonRecipeTextEditSettings{:}, ...
                        'Position', [145, 18*(ii-1)+5, textEditWidth, 17], ...
                        'TooltipString', obj.recipeToolTips{ii}, ...
                        'Tag', obj.recipePropertyNames{ii}); %The tag is used by obj.updateRecipePropertyInRecipeClass to update the recipe

                elseif strcmp(thisProp{2},'sampleSize')

                    %We need a separate X and Y box for the sample size
                    obj.recipeTextLabels.(thisProp{1}).([thisProp{2},'X']) = obj.makeRecipeLabel([152,18*(ii-1)+7,10,18],'X=');
                    obj.recipeTextLabels.(thisProp{1}).([thisProp{2},'Y']) = obj.makeRecipeLabel([215,18*(ii-1)+7,10,18],'Y=');

                    obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'X']) = ...
                    uicontrol(commonRecipeTextEditSettings{:}, ...
                        'Position', [160, 18*(ii-1)+5, 30, 17], ...
                        'TooltipString', obj.recipeToolTips{ii}, ...
                        'Tag', [obj.recipePropertyNames{ii},'||X']);

                    obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'Y']) = ...
                    uicontrol(commonRecipeTextEditSettings{:}, ...
                        'Position', [225, 18*(ii-1)+5, 30, 17], ...
                        'TooltipString', obj.recipeToolTips{ii}, ...
                        'Tag', [obj.recipePropertyNames{ii},'||Y']);
                end

            end
            if obj.suppressToolTips
                %just wipe them all
                p=fields(obj.recipeEntryBoxes);
                for ii=1:length(p)
                    tmp=obj.recipeEntryBoxes.(p{ii});
                    pp=fields(tmp);
                    for kk=1:length(pp)
                        set(tmp.(pp{kk}),'TooltipString','')
                    end
                end
            end

            %Fill it in with the recipe
            obj.updateAllRecipeEditBoxes

            obj.connectRecipeListeners %It's a method because we have to close and re-connect when we load a new recipe


            %TODO: the following listeners are temporary. We need to have SIBT handle this ScanImage stuff
            if obj.model.isScannerConnected && isa(obj.model.scanner,'SIBT')
                obj.connectScanImageListeners
            end

        end %close constructor


        function delete(obj,~,~)
            fprintf('BakingTray.gui.view is cleaning up\n')
            cellfun(@delete,obj.listeners)

            %Delete all attached views
            delete(obj.view_laser)
            delete(obj.view_prepare)
            delete(obj.view_acquire)

            delete(obj.model);
            obj.model=[];

            delete(obj.hFig);

            %clear from base workspace if present
            evalin('base','clear hBT hBTview')
        end %close destructor

        function closeBakingTray(obj,~,~)
            %Confirm and quit BakingTray (also closing the model and so disconnecting from hardware)
            %This method runs when the user presses the close 
            choice = questdlg('Are you sure you want to quit BakingTray?', '', 'Yes', 'No', 'No');

            switch choice
                case 'No'
                    %pass
                case 'Yes'
                    obj.delete
            end
        end
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -



        % -----------------------
        % Recipe-related methods
        function updateAllRecipeEditBoxes(obj,~,~)
            %If any recipe property is updated in model.recipe we update all the edit boxes
            %and any relevant GUI elements. We also modify elements in other attached GUIs
            %if this is needed
            if ~obj.model.isRecipeConnected
                return
            end

            R=obj.model.recipe;

            for ii=1:length(obj.recipePropertyNames)
                thisProp = strsplit(obj.recipePropertyNames{ii},'||');
                if ~strcmp(thisProp{2},'sampleSize')
                    obj.recipeEntryBoxes.(thisProp{1}).(thisProp{2}).String = R.(thisProp{1}).(thisProp{2});
                elseif strcmp(thisProp{2},'sampleSize')
                    obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'X']).String = R.(thisProp{1}).(thisProp{2}).X;
                    obj.recipeEntryBoxes.(thisProp{1}).([thisProp{2},'Y']).String = R.(thisProp{1}).(thisProp{2}).Y;
                end
            end
            obj.updateStatusText

            %Now update the prepare GUI if this is present: cutting speed and thickness labels should be
            %green if they match those in the recipe
            if ~isempty(obj.view_prepare) && isvalid(obj.view_prepare)
                obj.view_prepare.checkSliceThicknessEditBoxValue
                obj.view_prepare.checkCuttingSpeedEditBoxValue
            end

            %Set the current section number to be equal to the start number
            %TODO: this may be creating a problem. I notice that the current section number is not updating and is stuck at 1. This might be why.
            %obj.model.currentSectionNumber=obj.model.recipe.mosaic.sectionStartNum;

        end %updateAllRecipeEditBoxes

        function updateRecipePropertyInRecipeClass(obj,eventData,~)
            %Replace a property in obj.model.recipe with the value the user just changed

            %Keeps strings as strings but converts numbers
            newValue=str2double(eventData.String);
            if isnan(newValue)
                newValue=eventData.String;
            end

            %Where to put this?
            propertyPath = strsplit(eventData.Tag,'||');

            if length(propertyPath)==2
                obj.model.recipe.(propertyPath{1}).(propertyPath{2})=newValue;
            elseif length(propertyPath)==3
                obj.model.recipe.(propertyPath{1}).(propertyPath{2}).(propertyPath{3})=newValue;
            else
                fprintf('ERROR IN BakingTray.gui.view.updateRecipePropertyInRecipeClass: property path is not 2 or 3\nCan not set recipe property!\n')
                return
            end
        end



        %-----------
        % Button callbacks
        %send vars to base workspace


        function startLaserGUI(obj,~,~)
            %Present error dialog if no laser is connected (button should be disabled anyway)
            if ~obj.model.isLaserConnected
                warndlg('No laser connected to BakingTray','')
                return
            end

            %Only start GUI if one doesn't already exist
            if isempty(obj.view_laser) || ~isvalid(obj.view_laser)
                obj.view_laser=BakingTray.gui.laser_view(obj.model);
            else
                figure(obj.view_laser.hFig) % Raise and bring to focus laser GUI
            end
        end

        function startPrepareGUI(obj,~,~)
            %Do not start the prepare GUI if an acquisition in progress
            if obj.model.acquisitionInProgress
                warndlg('An acquisition is in progress. Can not start Sample Prepare GUI.','')
                return
            end

            %Do not start the prepare GUI unless all the required components are present
            msg = obj.model.checkForPrepareComponentsThatAreNotConnected;

            if ~isempty(msg) %We can't start because components are missing. Report which ones:
                msg = ['Can not start sample preparation:\n',msg];
                warndlg(sprintf(msg),'')
                return
            end
            if isempty(obj.view_prepare) || ~isvalid(obj.view_prepare)
                obj.view_prepare=BakingTray.gui.prepare_view(obj.model,obj);
            else
                figure(obj.view_prepare.hFig)
            end
        end

        function loadRecipe(obj,~,~)
            % Load recipe button callback -- loads a new recipe from disk
            [fname,absPath] = uigetfile('*.yml','Choose a recipe',BakingTray.settings.settingsLocation);
            fullPath = fullfile(absPath,fname);

            %Does this path already contain an acquisition?
            [containsAcquisition,details] = BakingTray.utils.doesPathContainAnAcquisition(absPath);
            doResume=false;
            if containsAcquisition
                reply=questdlg('Resume acquisition in this directory?','');
                if strcmpi(reply,'yes')
                    doResume=true;
                end
            end

            obj.detachRecipeListeners;
            if ~doResume
                % Just load as normal
                success = obj.model.attachRecipe(fullPath);
            else
                % Attempt to set up for resuming the acquisition
                success = obj.model.attachRecipe(fullPath,true); % sets resume flag to true
                % TODO: set the section start number and num sections
                % TODO: decide if we need to move in Z
                % TODO: get the last x/y tile so start from there
            end

            if success
                obj.connectRecipeListeners
                obj.updateAllRecipeEditBoxes
                obj.updateRecipeFname
            end
        end %loadRecipe



        function START(obj,~,~)
            %TODO: handle the scenario where the user is resuming an old acquisition and 
            %has not gone through the preparation phase
            if isempty(obj.view_prepare)
                %THe user must be resuming since they never prepared anything
                 warndlg('You prepared nothing. Resuming an acquisition is not yet supported via the GUI','');
                 return
            end

            % Raise a warning if it appears the user prepared the sample with cutting parameters
            % different from those the imaging acquisition will use. This scenario can lead
            % to the brain surface moving away from where it currently is. 
            lastThickness=obj.model.recipe.lastSliceThickness;
            warnMsg='';
            if ~isempty(lastThickness)
                if lastThickness~=obj.model.recipe.mosaic.sliceThickness
                    warnMsg=[warnMsg,sprintf('You will be cutting %0.2f sections but you seem to have prepared the sample at %0.2f.\n',...
                        obj.model.recipe.mosaic.sliceThickness, lastThickness)];
                    fprintf(warnMsg)
                end
            end

            lastCutSpeed=obj.model.recipe.lastCuttingSpeed;
            if ~isempty(lastCutSpeed)
                if lastCutSpeed~=obj.model.recipe.mosaic.cuttingSpeed
                    warnMsg=[warnMsg,sprintf('You will be cutting at %0.2f mm/s but you seem to have prepared the sample at %0.2f mms/s.\n',...
                        obj.model.recipe.mosaic.cuttingSpeed, lastCutSpeed)];
                    fprintf(warnMsg)
                end
            end

            %The confirmation dialog will incorporate messages from the above two warning scenarios if they are present. 
            %Final start comes in the next GUI
            if ~isempty(warnMsg)
                choice = questdlg([warnMsg,'Are you sure you want to start acquisition?'], '', 'Yes', 'No', 'No');
                switch choice
                    case 'No'
                        return
                    case 'Yes'
                end
            end

            %Open an acquisition view if it's not already been opened
            if isempty(obj.view_acquire) || ~isvalid(obj.view_acquire)
                obj.view_acquire=BakingTray.gui.acquisition_view(obj.model,obj);
            else
                %otherwise raise it (TODO: currently not possible since button is disabled when acq GUI starts)
                figure(obj.view_acquire.hFIg)
            end
        end %START


        %The following methods are callbacks from the menu
        function copyAPItoBaseWorkSpace(obj,~,~)
            fprintf('\nCreating API access components in base workspace:\nmodel: hBT\nview: hBTview\n\n')
            assignin('base','hBTview',obj)
            assignin('base','hBT',obj.model)
        end

        function connectScanImage(obj,~,~)
            if obj.model.isScannerConnected && isa(obj.model.scanner,'SIBT')
                warndlg('ScanImage already connected','')
                return
            elseif obj.model.isScannerConnected
                warndlg(sprintf('%s already connected',class(obj.model.scanner)),'')
                return
            end

            scanimageObjectName='hSI';
            W = evalin('base','whos');
            SIexists = ismember(scanimageObjectName,{W.name});
            if ~SIexists
                warndlg('You should start ScanImage first','')
                return
            end

            success=obj.model.attachScanner;
            if ~success
                warndlg(sprintf('Failed to attach ScanImage.\nLook for errrors at the terminal.'),'')
            end
            obj.connectScanImageListeners
            obj.updateStatusText; %TODO: this might become recursive in future. WARNING!
        end %connectScanImage


        function saveRecipeToDisk(obj,~,~)
            %Save recipe to disk. Open the default settings directory.
            [fname,pathToRecipe] = uiputfile('*.yml',BakingTray.settings.settingsLocation);
            obj.model.recipe.saveRecipe(fullfile(pathToRecipe,fname));
        end %saveRecipeToDisk

    end %Methods





    methods (Hidden)
        function about(~,~,~)
            %Generate an "about" box
            h = msgbox(sprintf('BakingTray\nAutomated anatomy'));
            h.Position(3:4)=[240,90];
            ch = get(get(h,'CurrentAxes'), 'Children');
            set(ch, 'FontSize', 20 );
        end

        function changeDir(obj,~,~)
            % The dir selector should open at the current save path by default
            if ~isempty(obj.model.sampleSavePath) && exist(obj.model.sampleSavePath,'dir')
                startPath = obj.model.sampleSavePath;
            else
                startPath = pwd;
            end
            thisDir = uigetdir(startPath,'choose dirctory');
            if ischar(thisDir) && exist(thisDir,'dir')
                obj.model.sampleSavePath = thisDir;
                %Escape underscores and forward slashes
                thisDir= regexprep(thisDir,'([\\_])','\\$1');
                obj.text_sampleDir.String=thisDir;
            end
        end

        function updateRecipeFname(obj,~,~)
            if obj.model.isRecipeConnected
                [~,recipeFname,ext]=fileparts(obj.model.recipe.fname);
                recipeFname = [strrep(recipeFname,'_','\_'),ext]; %escape underscores
                set(obj.text_recipeFname,'String', recipeFname)
            end
        end

        function updateStatusText(obj,~,~)
            if obj.model.isRecipeConnected
                R=obj.model.recipe;

                scannerID=obj.getScannerID;
                if scannerID ~= false
                    %If the user is to run ScanImage, prompt them to start it
                    scnSet = obj.model.scanner.returnScanSettings;
                else 
                    settings=BakingTray.settings.readComponentSettings;
                    if strcmp(settings.scanner.type,'SIBT')
                        scannerID='START SCANIMAGE AND CONNECT IT';
                    else
                        scannerID='NOT ATTACHED';
                    end
                    scnSet=[];
                end

                if ~obj.model.isScannerConnected
                    warndlg('Can not generate tile positions: no scanner connected.','')
                end

                micronsBetweenOpticalPlanes = (R.mosaic.sliceThickness/R.mosaic.numOpticalPlanes)*1000;

                if ~isempty(scnSet)
                    msg = sprintf(['System ID: %s ; Scanner: %s\n', ...
                        'Voxel Size: %0.1f x %0.1f x %0.1f \\mum ;', ...
                        ' FOV: %d x %d \\mum \n'], ...
                        R.SYSTEM.ID, scannerID, scnSet.micronsPerPixel_cols, ...
                        scnSet.micronsPerPixel_rows, micronsBetweenOpticalPlanes, ...
                        round(scnSet.FOV_alongColsinMicrons), ...
                        round(scnSet.FOV_alongRowsinMicrons));

                elseif ~isempty(scnSet)
                    endTime=obj.model.estimateTimeRemaining;

                    msg = sprintf(['System: %s ; Scanner: %s\n', ...
                        'FOV: %d x %d\\mum ; Voxel: %0.1f x %0.1f x %0.1f \\mum\n', ...
                        'Tiles: %d x %d ; Depth: %0.1f mm\n',...
                        'Section time: %s\n', ...
                        'Total time left: %s\n'], ...
                        R.SYSTEM.ID, scannerID, ...
                        round(scnSet.FOV_alongColsinMicrons), ...
                        round(scnSet.FOV_alongRowsinMicrons), ...
                        scnSet.micronsPerPixel_cols, scnSet.micronsPerPixel_rows, micronsBetweenOpticalPlanes, ...
                        R.NumTiles.X, R.NumTiles.Y, R.mosaic.sliceThickness*R.mosaic.numSections, ...
                        endTime.timePerSectionString, endTime.timeForSampleString);

                elseif isempty(scnSet)
                    msg = sprintf('System ID: %s ; Scanner: %s', R.SYSTEM.ID, scannerID);
                end

                set(obj.text_status,'String', msg)
            end 
        end %updateStatusText


        function updateReadyToAcquireElements(obj,~,~)
            if obj.model.recipe.acquisitionPossible
                obj.button_start.String='START';
                obj.button_start.ForegroundColor=[0,0.75,0];
            else ~obj.model.recipe.acquisitionPossible
                obj.button_start.String='Start';
                obj.button_start.ForegroundColor='k';
            end
        end %updateReadyToAcquireElements


        function ID = getScannerID(obj)
            %returns false if no scanner is connected
            %otherwise returns scanner name
            if obj.model.isScannerConnected
                ID=class(obj.model.scanner);
            else
                ID=false;
            end
        end %getScannerID


        %The following are helper methods for building the GUI. They have no other uses
        function thisLabel = makeRecipeLabel(obj,position,labelString)
            thisLabel =annotation(obj.recipePanel, 'textbox', ...
                    'Units', 'pixels', ...
                    'Position', position, ...
                    'EdgeColor', 'none', ...
                    'HorizontalAlignment', 'Right', ...
                    'Color', 'w', ...
                    'FontSize', obj.fSize, ...
                    'FitBoxToText','off', ...
                    'String', labelString);
        end %makeRecipeLabel



        function enableDisableThisView(obj,enableState)
            % Toggles the enable/disable state on all buttons and edit boxes. 
            % This method is called by the acquire GUI to ensure that whilst
            % it is open it is not possible to modify the recipe.
            if nargin<2 && ~strcmp(enableState,'on') && ~strcmp(enableState,'off')
                return
            end
            entryBoxFields=fields(obj.recipeEntryBoxes);
            for ii=1:length(entryBoxFields)
                theseFields=fields(obj.recipeEntryBoxes.(entryBoxFields{ii}));
                for kk=1:length(theseFields)
                    obj.recipeEntryBoxes.(entryBoxFields{ii}).(theseFields{kk}).Enable=enableState;
                end
            end
            %The laser button should always be enabled
            obj.button_chooseDir.Enable=enableState;
            obj.button_recipe.Enable=enableState;
            obj.button_prepare.Enable=enableState;
            obj.button_start.Enable=enableState;
        end %enableDisableThisView



        % -------------------------------------------------------------------------------------------------------
        %Below are methods that handle the listeners
        function connectRecipeListeners(obj)
            % Add listeners to update the values on screen should they change
            obj.listeners{1}=addlistener(obj.model.recipe, 'sample', 'PostSet', @obj.updateAllRecipeEditBoxes);
            obj.listeners{2}=addlistener(obj.model.recipe, 'mosaic', 'PostSet', @obj.updateAllRecipeEditBoxes);

            %If the recipe signals a change in recipe.acquisitionPossible, we update the start button etc
            obj.listeners{3}=addlistener(obj.model.recipe, 'acquisitionPossible', 'PostSet', @obj.updateReadyToAcquireElements);
        end %connectRecipeListeners

        function detachRecipeListeners(obj)
            for ii=1:3
                delete(obj.listeners{ii})
            end
        end %detachRecipeListeners

        function connectScanImageListeners(obj)
            %TODO: the following listeners are temporary. We need to have SIBT handle this ScanImage stuff
            hSI=obj.model.scanner.hC;
            obj.listeners{4}=addlistener(hSI.hRoiManager, 'scanZoomFactor', 'PostSet', @obj.updateAllRecipeEditBoxes);
            obj.listeners{5}=addlistener(hSI.hRoiManager, 'scanFrameRate', 'PostSet', @obj.updateAllRecipeEditBoxes);
        end %connectScanImageListeners


    end %Hidden methods




end
