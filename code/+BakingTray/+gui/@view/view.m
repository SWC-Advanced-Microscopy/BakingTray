classdef view < handle

    % BakingTray.gui.view is the main GUI window: that which first appears when the 
    % user starts the software. It's goal is to house the "recipe" parameters which 
    % set out the acquisition will proceed. It also allows the opening of GUI 
    % windows for control of stages, previewing the sample, etc. Closing the main
    % GUI window quits BakingTray.


    properties
        hFig
        model % The BT model object goes here

        % Buttons attach to these properties
        button_chooseDir
        button_laser
        button_recipe
        button_prepare
        button_start

        view_laser      % The laser GUI object is stored here
        view_prepare    % The prepare GUI object is stored here
        view_acquire    % The acquisition GUI object is stored here
        view_channelChooser % The channelChooser GUI

        % Text display boxes
        text_sampleDir
        text_recipeFname

        text_status

        recipeTextLabels=struct % Annotation text boxes with labels of recipe fields
        recipeEntryBoxes=struct % The user enters recipe values here

        % Top menu
        menu
    end



    properties(Hidden)
        timerUpdateInterval=0.33 %Any timers will update the GUI every so many seconds
        fSize=12;

        listeners={}
        recipeListeners={}
        scannerListeners={}



        % These properties are used to build and populate the recipe fields
        % see the populateRecipePanel method.
        recipePropertyNames
        recipeFieldLabels
        recipeToolTips

        %Panels
        basicSetupPanel %house dir and recipe buttons 
        hardwarePanel %houses buttons that will do stuff to hardware
        statusPanel  %For now this will house a general purpose display box - just dump a big text string into it 
        recipePanel %recipe editing goes here

        suppressToolTips=false
        allowChannelChooser=false % If true the channel chooser appears in the Tools menu.
    end

    % Declare methods and callbacks in separate files
    methods (Hidden)
        buildWindow(obj)  % Used once by the constructor
        populateRecipePanel(obj) % Used once by the constructor
        out = updateTileSizeLabelText(obj,scnSet) % helper for callbacks
        enableDisableThisView(obj,enableState)
        importFrameSizeSettings(obj)

        % Recipe-related callback methods
        updateAllRecipeEditBoxesAndStatusText(obj,evt,src)
        updateRecipePropertyInRecipeClass(obj,evt,src)
        displayMessage(obj,~,~)

        % Button callback functions
        startPreviewSampleGUI(obj,evt,src)
        newSample(obj,evt,src)
        loadRecipe(obj,evt,src,pathToRecipe)
        startPrepareGUI(obj,evt,src)
        startLaserGUI(obj,evt,src)

        % Other callbacks
        updateStatusText(obj,evt,src)
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

            % Make empty cell arrays that will be used later
            obj.recipeTextLabels.other={}; % Labels that aren't part of the recipe go into this cell array
            obj.recipeEntryBoxes.other={}; % As above but for the entry boxes



            % Build the window
            obj.buildWindow;

            % Add a listener to the sampleSavePath property of the BT model
            obj.listeners{end+1} = addlistener(obj.model, 'sampleSavePath', 'PostSet', @obj.updateSampleSavePathBox);

            % Update the status text whenever the BT.isSlicing property changes. This will only happen twice per section.
            % This ensures that the time left string updates
            obj.listeners{end+1} = addlistener(obj.model, 'isSlicing', 'PostSet', @obj.updateStatusText);

            obj.listeners{end+1} = addlistener(obj.model, 'acquisitionInProgress', 'PostSet', @obj.disableDuringAcquisition);

            % Displays messages in a warning dialog box
            obj.listeners{end+1}=addlistener(obj.model, 'messageString', 'PostSet', @obj.displayMessage);

            obj.updateStatusText;
            if obj.model.isScannerConnected
                obj.connectScannerListeners
            end
            
            % Finally we make sure that the scanner is set to the default
            % resolution displayed in BakingTrau
            obj.applyScanSettings(obj.recipeEntryBoxes.other{1});
        end %close constructor


        function delete(obj,~,~)
            fprintf('BakingTray.gui.view is cleaning up\n')
            cellfun(@delete,obj.listeners)
            cellfun(@delete,obj.recipeListeners)
            cellfun(@delete,obj.scannerListeners)

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



        %The following methods are callbacks from the menu
        function copyAPItoBaseWorkSpace(obj,~,~)
            fprintf('\nCreating API access components in base workspace:\nmodel: hBT\nview: hBTview\n\n')
            assignin('base','hBTview',obj)
            assignin('base','hBT',obj.model)
        end %copyAPItoBaseWorkSpace


        function referenceStages(obj,~,~)
            % Reference stages if needed
            [allReferenced,ST] = obj.model.allStagesReferenced;
            if allReferenced
                % No stages need referencing
                msgbox('All stage axes are referenced')
            else
                if length(ST)==1
                    msg = sprintf('1 axis needs referencing.\n');
                else
                    msg = sprintf('%d axes need referencing.\n',length(ST));
                end
                OUT=questdlg(sprintf('%sRemove water bath and press START.',msg), ...
                    '','START','Cancel','Cancel');
                if strcmp(OUT,'START')
                    obj.model.referenceRequiredAxes(ST);
                end
            end
        end %referenceStages


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
            obj.connectScannerListeners
            obj.updateStatusText; %TODO: this might become recursive in future. WARNING!
        end %connectScanImage


        function resumeAcq(obj,~,~)
            % Resume an acquisition. This just loads the recipe but does so using the default save
            % path as the default directory.
            obj.loadRecipe([],[],obj.getDefaultSavePath)
        end %resumeAcq


        function saveRecipeToDisk(obj,~,~)
            %Save recipe to disk. Open the default settings directory. This is a callback from a menu
            [fname,pathToRecipe] = uiputfile('*.yml',BakingTray.settings.settingsLocation);
            if fname==0
                return
            end
            obj.model.recipe.saveRecipe(fullfile(pathToRecipe,fname));
        end %saveRecipeToDisk


        function changeDir(obj,~,~)
            % The dir selector should open at the system default save path by default otherwise it uses the 
            % last model.sampleSavePath and failing that the current directory
            thisDir = uigetdir(obj.getDefaultSavePath,'choose dirctory');

            if thisDir==0 || ~exist(thisDir,'dir')
                return
            end

            if ischar(thisDir) && exist(thisDir,'dir')
                obj.model.sampleSavePath = thisDir; % The GUI itself is changed via a listener defeined in the constructor
            end

            % Set the directory name to be the sample name
            [~,tDirName] = fileparts(thisDir);
            obj.model.recipe.sample.ID = tDirName;
        end % changeDir


        function savePath = getDefaultSavePath(obj)
            % Get the default save path. If it is available in the system settings file and
            % is valid, use that. 
            if ~isempty(obj.model.recipe.SYSTEM.defaultSavePath) &&  exist(obj.model.recipe.SYSTEM.defaultSavePath,'dir')
                savePath = obj.model.recipe.SYSTEM.defaultSavePath;
            elseif ~isempty(obj.model.sampleSavePath) && exist(obj.model.sampleSavePath,'dir')
                savePath = obj.model.sampleSavePath;
            else
                savePath = pwd;
            end
        end % getDefaultSavePath
    end %Methods





    methods (Hidden)

        function updateRecipeFname(obj,~,~)
            if obj.model.isRecipeConnected
                [~,recipeFname,ext]=fileparts(obj.model.recipe.fname);
                recipeFname = [strrep(recipeFname,'_','\_'),ext]; %escape underscores
                set(obj.text_recipeFname,'String', recipeFname)
            end
        end


        function updateSampleSavePathBox(obj,~,~)
            % Runs via a listener when BT.sampleSavePath changes
            savePath = obj.model.sampleSavePath;
            if ~isempty(savePath) && ischar(savePath)
                % Escape underscores and forward slashes
                obj.text_sampleDir.String = regexprep(savePath,'([\\_])','\\$1');
            end
        end


        function updateReadyToAcquireElements(obj,~,~)
            if obj.model.recipe.acquisitionPossible
                obj.button_start.ForegroundColor=[0,0.75,0];
            else
                obj.button_start.ForegroundColor='k';
            end
        end %updateReadyToAcquireElements


        function disableDuringAcquisition(obj,~,~)
            % Callback to disable the view when an acquisition is in progress
            if obj.model.acquisitionInProgress
                obj.enableDisableThisView('off')
            else 
                obj.enableDisableThisView('on')
            end
        end % disableDuringAcquisition


        function applyScanSettings(obj,src,~)
            % Apply the chosen scan settings to ScanImage and send the current stitching settings
            % to the recipe. TODO: This method performs critical tasks that should not be done by a view class. 
            %                      To maintain the model/view separation the recipe operation should be done
            %                      elsewhere. Maybe in BT or the recipe class itself.

            if ~obj.model.isScannerConnected
                return
            end

            % Disable the listeners on the scanner temporarily otherwise 
            % we get things that look like error messages
            obj.scannerListeners{1}.Enabled=false; 

            %Set the scanner settings
            obj.model.scanner.setImageSize(src)

            obj.scannerListeners{1}.Enabled=true;
            %Send copies of stitching-related data to the recipe
            obj.model.recipe.recordScannerSettings;

            obj.updateAllRecipeEditBoxesAndStatusText %Manually call scanner listener callback
            obj.updateTileSizeLabelText;
        end


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




        % -------------------------------------------------------------------------------------------------------
        %Below are methods that handle the listeners
        function connectRecipeListeners(obj)
            % Add listeners to update the values on screen should they change
            obj.recipeListeners{end+1}=addlistener(obj.model.recipe, 'sample', 'PostSet', @obj.updateAllRecipeEditBoxesAndStatusText);
            obj.recipeListeners{end+1}=addlistener(obj.model.recipe, 'mosaic', 'PostSet', @obj.updateAllRecipeEditBoxesAndStatusText);

            %If the recipe signals a change in recipe.acquisitionPossible, we update the start button etc
            obj.recipeListeners{end+1}=addlistener(obj.model.recipe, 'acquisitionPossible', 'PostSet', @obj.updateReadyToAcquireElements);
        end %connectRecipeListeners


        function detachRecipeListeners(obj)
            % Detach all listeners related to the recipe
            cellfun(@delete,obj.recipeListeners)
            obj.recipeListeners={};
        end %detachRecipeListeners


        function connectScannerListeners(obj)
            % Connect any required listeners to ScanImage
            if ~isempty(obj.scannerListeners)
                cellfun(@delete,obj.scannerListeners)
                obj.scannerListeners={};
            end
            obj.scannerListeners{end+1}=addlistener(obj.model.scanner, 'scanSettingsChanged', 'PostSet', @obj.updateAllRecipeEditBoxesAndStatusText);
        end %connectScannerListeners


    end %Hidden methods

end % close classdef
