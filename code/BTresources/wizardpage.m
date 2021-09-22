classdef wizardpage < handle
%% wizardpage
%
% The wizardpage superclass is to be inherited by all wizard pages.
% Each page of the wizard is a separate UI and each inherits wizardpage
    properties
  

    end % properties

    properties (SetObservable)
        graphicsHandles
        validAnswersStruct % A structure of bools indicating which page elements are valid and which invalid.
        isValid = false % Set to true when the form is valid. This is set automatically based on validAnswerStruct
    end

    properties (Hidden)
      % The following are just convenience references or copes of elements in the main wizard
        hNextButton
        hPreviousButton
        hPagePanel
        currentPage

        mainWizardGUI % Finally a reference to the wizard page itself that includes the above

        listeners = {}
    end


    methods

        function obj = wizardpage(mainWizardGUI)
            % wizardpage constructor
            %
            % Inputs
            % mainWizardGUI - a reference to the main wizard object to which the wizardpage is attached

            if nargin<1
                return
            end 

            if ~isa(mainWizardGUI,'wizard')
                return
            end 
            
            % Make local convenience references
            obj.hNextButton = mainWizardGUI.hNextButton;
            obj.hPreviousButton = mainWizardGUI.hPreviousButton;
            obj.hPagePanel = mainWizardGUI.hPagePanel;
            obj.currentPage = mainWizardGUI.currentPage;
            obj.mainWizardGUI = mainWizardGUI;
            
            obj.listeners{end+1} = addlistener(obj, 'validAnswersStruct', 'PostSet', @obj.checkValidAnswers);
            obj.listeners{end+1} = addlistener(obj, 'isValid', 'PostSet', @obj.updateNextButtonWhenValid);    
        end % wizardpage constructor


        function delete(obj)
            % This is the "destructor". It runs when an instance of the class comes to an end.
            cellfun(@delete,obj.listeners)

            if ~isempty(obj.graphicsHandles) && isstruct(obj.graphicsHandles)
                f=fields(obj.graphicsHandles);
                for ii=1:length(f)
                    delete(obj.graphicsHandles.(f{ii}))
                end
            end
        end % delete


        function checkValidAnswers(obj,~,~)
            % wizardpage.checkValidAnswers
            %
            % Behavior
            % Sets wizardpage.isValid to true if all booleans in validAnswersStruct are true.
            % If isValid is true the Next button is enabled. Otherwise the Next button is 
            % disabled. checkValidAnswers automatically sets isValid to true if all fields
            % in the wizardpage.validAnswersStruct structure are true. TODO:  This is somewhat 
            % constraining but for now it's possible to work around it so we leave as is. 
            if isempty(obj.validAnswersStruct)
                obj.isValid = false;
                return
            end

            if islogical(obj.validAnswersStruct)
                obj.isValid = obj.validAnswersStruct;
                return
            end

            if isstruct(obj.validAnswersStruct)
                tFields = fields(obj.validAnswersStruct);
                tBools = zeros(1,length(tFields),'logical');
                for ii=1:length(tFields)
                    tBools(ii) = obj.validAnswersStruct.(tFields{ii});
                end

                obj.isValid = all(tBools == true);
            end

        end %checkValidAnswers


        function updateNextButtonWhenValid(obj,~,~)
            % wizardpage.updateNextButtonWhenValid
            %
            % Behavior
            % If wizardpage.isValid is true the Next button is enabled. Otherwise it is
            % disabled. 

            if obj.isValid == true
                obj.hNextButton.Enable = 'on';
            else 
                obj.hNextButton.Enable = 'off';
            end
        end %updateNextButtonWhenValid


        function dataReapplied = reapplyCachedData(obj)
            % wizardpage.reapplyCachedData
            %
            % Behavior
            % If the user goes back to previous pages, reapplyCachedData applied again 
            % last valid settings the user made. 
            %
            % Outputs
            % dataReapplied is true if data were reapplied. False otherwise.
            %
            % Notes
            % This method must be run at the end of the constructor of the class that 
            % inherits wizardpage. This ensures that any cached values are re-applied. 

            dataReapplied = false;
            if length(obj.mainWizardGUI.cachedData)<obj.currentPage
                return
            end 

            if isempty(obj.mainWizardGUI.cachedData{obj.currentPage})
                return
            end
               
            cachedData = obj.mainWizardGUI.cachedData{obj.currentPage};
            if ~isstruct(cachedData)
                return
            end

            tFields = fields(cachedData);

            for ii = 1:length(tFields)
                tagName = tFields{ii};
                cData = cachedData.(tagName);
                UI = findobj(obj.mainWizardGUI.hFig,'Tag',tagName);
                UI.(cData.UIprop) = cData.value;
                obj.validAnswersStruct.(tagName) = true; %If it was stored it must be valid
            end
            dataReapplied = true;
        end %reapplyCachedData


        function cacheVals(obj,src,~)
            % wizardpage.cacheVals
            % 
            % Behavior
            % This is a callback function that caches values for re-use should the user go
            % back and forth through a wizard. This method may, of course, be run as a conventional
            % method instead of a callback. In this case the user must explicitly supply the 
            % UI element to cachce as an input argument.
            % 
            % This method has only been tested against the following UI elements made using "uicontrol":
            % - edit boxes
            % - popup menus
            % - checkboxes
            % 
            %
            % Inputs
            % src  - The UI element to cache. 


            % Cache values based on what the UI element was
            if isa(src,'matlab.ui.control.UIControl')
                switch src.Style
                case 'edit'
                    obj.mainWizardGUI.cachedData{obj.currentPage}.(src.Tag).UIprop = 'String';
                    obj.mainWizardGUI.cachedData{obj.currentPage}.(src.Tag).value = src.String;
                case {'popupmenu','checkbox'}
                    obj.mainWizardGUI.cachedData{obj.currentPage}.(src.Tag).UIprop = 'Value';
                    obj.mainWizardGUI.cachedData{obj.currentPage}.(src.Tag).value = src.Value;
                    obj.mainWizardGUI.cachedData{obj.currentPage}.(src.Tag).String = src.String;
                end
            end

            % Since we cached it, it must be a valid value so we full in the bool
            obj.validAnswersStruct.(src.Tag)=true;

        end % cacheVals

    end % methods

end % classdef
