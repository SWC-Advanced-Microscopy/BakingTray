classdef (Abstract) wizard  < handle
%%  wizard
%
% The wizard superclass defines basic behaviors associated with building a GUI wizard. 
%
% What is it?
% wizard is a low-level framework for making GUI wizards using pure MATLAB and 
% no GUI designer tools. The framework is highly flexible but requires the 
% developer to be skilled in object oriented programming. For those less familiar
% with OO, the class contains extensive comments.
% 
%
% Behavior
% This class defines a figure canvas that contains a "Previous" and "Next"  button
% so the user can navigate between multiple pages in the GUI. The Next button is
% automatically disabled on pages that require valid user input before proceeding. 
% The Next button becomes a "Done" button on the final page. When Done is clicked
% the GUI closes. Closing the GUI window at any time runs the destructor. 
%
% Each page of the GUI is a class that inherits the wizardpage superclass. There
% should be one class definition file per page. Page order is defined via a 
% series of function handles to class names stored in the wizard.pageConstructors
% cell array. 
%
% Output from the wizard is handled in two main ways. The most basic approach 
% is that confiuguration options are stored in the wizard.output property. If this
% property is non-empty it is written to the base workspace as the variable 
% "wizardoutput" when the Done button is pressed. For an example that uses this
% approach see plotWizard example. The second approach is that the user creates 
% compound class that allows the wizard to interact directly with model and/or
% view objects of an already running application (Google "model/view programing"
% if unfamiliar). In this latter scenario the user could design a wizard that 
% implements changes in the model each time the Next button is pressed, each 
% time a valid entry is made in a uicontrol, or simple to implement all changes
% when Done is pressed. 
% 
% 
%
%
% Rob Campbell - SWC 2021


    properties 
        hFig         % Handle to the wizard figure window
        hPagePanel   % All elements from one GUI pages should go into this panel
        pageElements % All GUI elements associated with one wizard page go here. This is a reference to an object that inherits wizardpage

        % The next and previous page buttons are present on every page and are not deleted.
        % These buttons should be children of hFig. They are build in the constructor of this
        % abstract class but will probably need to be moved later by the concrete classes 
        % that instantiate the object.
        hNextButton
        hPreviousButton

        pageConstructors = {} % A cell array of function handles for constructing each page

        output = []; %Optional output from wizard. If non-empty this placed in the base workspace as a variable called 'wizardoutput'
        cachedData = {} % Cell array of structures used to record user resposes to previous wizard pages. e.g.
                          % obj.cachedValues{obj.currentPage}.(tagName).UIprop = 'string'
                          % obj.cachedValues{obj.currentPage}.(tagName).value = 'some text data'
                          % Other data can also be stored in extra fields if the user wishes. But the above two are needed. 
                          % see also: wizardpage.reapplyCachedData
    end %close public properties


    properties (SetObservable,Hidden)
        currentPage = 1 % Index of the current page number 
        allDataValidOnCurrentPage = false % Used to determine whether the "Next" button may be enabled
    end


    properties (Hidden)
        listeners = {} % All listeners to go in this cell array from which they are tidied upon object destruction
    end %close hidden properties


    methods

        function obj = wizard()
            % Constructor
            % Make the next and previous buttons. It will be up to the user to later position them and set the properties

            obj.hFig = figure;
            %obj.hFig.HandleVisibility = 'callback'; %so it doesn't respond to "close all"
            obj.hFig.NumberTitle = 'off';
            obj.hFig.ToolBar = 'none';
            obj.hFig.MenuBar = 'none';            


            % Closing the figure deletes the class
            set(obj.hFig,'CloseRequestFcn', @obj.closeWizard)

            obj.hNextButton = uicontrol('Parent', obj.hFig, ... 
                            'Tag', 'Next', ...
                            'Position', [140,10,100,50], ...
                            'String', 'Next', ...
                            'Callback', @obj.nextPage);

            obj.hPreviousButton = uicontrol('Parent', obj.hFig, ... 
                            'Tag', 'Previous', ...
                            'Position', [10,10,100,50], ...
                            'String', 'Previous', ...
                            'Callback', @obj.previousPage);

            % Set up a listener on the currentPage property so it updates the buttons depending on 
            % our cuurent page number. 
            obj.listeners{end+1} = addlistener(obj, 'currentPage', 'PostSet', @obj.updateNextPrevious);

            % UI elements created by wizardPages go into this panel
            obj.hPagePanel = uipanel(...
                            'Parent', obj.hFig,...
                            'Units', 'pixels', ...
                            'Position', [10,60,540,350]);
        end % wizard constructor


        function delete(obj)
            % This is the "destructor". It runs when an instance of the class comes to an end.
            delete(obj.pageElements) % Tidy up the wizardPage
            delete(obj.hFig)         % Close the figure window
            cellfun(@delete,obj.listeners) % Ensure all listeners are deleted, as sometimes they become orphans

            % If the user has placed data in the output property, this is copied into the
            % base workspace as a variable called "wizardoutput".
            if ~isempty(obj.output)
                assignin('base','wizardoutput',obj.output)
            end
        end % delete


        function clearPage(obj)
            % wizard.clearPage
            %
            % Behavior
            % Removes all handles in pageElements from the current page.
            if isempty(obj.pageElements)
                return
            end
            if isa(obj.pageElements,'wizardpage') %must be true
                delete(obj.pageElements)
            end 
        end % clearPage


        function n = numPages(obj)
            % wizard.numPages
            %
            % Behavior
            % Returns the total number of pages in the current wizard. 
            %
            % Outputs
            % n - A scalar representing the total number of pages. 
            n = length(obj.pageConstructors);
        end % numPages


        function renderPage(obj,pageID)
            % wizard.renderPage
            %
            % Behavior
            % Clears the current page. Then draws a defined wizardPage that is fed in 
            % as a handle to a class or defined as an index position in the the cell 
            % array wizard.pageConstructors; in normal use pageID will be a scalar.
            % Once the page is rendered, the Next and Previous buttons are updated. 
            %
            % Inputs
            % pageID - Either a scalar corresponding to an index in wizard.pageConstructors 
            %       or a handle to a class the inherits wizardPage.

            obj.clearPage
            if isnumeric(pageID)
                % Get the class handle from the wizard.pageConstructors cell array
                if pageID<1 || pageID>length(obj.pageConstructors)
                    return
                end
                pageID=obj.pageConstructors{pageID};

            elseif isa(pageID,'function_hanle')
                % pageID is a handle so do nothing
            else
                fprintf('wizard.renderPage expected pageID to be a scalar or a function handle. It is a %s\n',  ...
                    class(pageID))
                return
            end

            % Instantiate the wizardPage and place a reference to in in the wizard.pageElements property
            obj.pageElements = pageID(obj);

            obj.updateNextPrevious;
        end % renderPage



        % Callbacks
        function updateNextPrevious(obj,~,~)
            % wizard.updateNextPrevious
            %
            % Behavior
            % Disables the Previous button if the wizard is on the first page. 
            % Converts the Next button to a Done button if the wizard is on the last page.
            if obj.numPages == 0
                return
            end

            if obj.currentPage == 1
                obj.hPreviousButton.Enable = 'off';
            elseif obj.currentPage > 1
                obj.hPreviousButton.Enable = 'on';
            end

            if obj.currentPage >= obj.numPages
                obj.hNextButton.String = 'Done';
            else
                obj.hNextButton.String = 'Next';
            end
        end % updateNextPrevious


        function nextPage(obj,~,~)
            % wizard.nextPage
            %
            % Purpose
            % This callback function increments the currentPage property then
            % triggers a GUI redraw based upon this number. If currentPage is
            % equal to the total number of pages, the "Next" button becomes a
            % "Done" button. Pressing the Done button will close the GUI without
            % warning. Done can only be pressed if all UI elements on the page
            % contain valid values. 
            %
            % See also
            % wizard.updateNextPrevious, wizard.reanderPage

            obj.currentPage = obj.currentPage+1;
            if obj.currentPage > obj.numPages
                obj.currentPage = obj.numPages;
                obj.delete
                return
            end
            obj.renderPage(obj.currentPage)
        end %nextPage


        function previousPage(obj,~,~)
            % wizard.previousPage
            %
            % Purpose
            % This callback function decrements the currentPage property then
            % triggers a GUI redraw based upon this number            
            %
            % See also
            % wizard.updateNextPrevious, wizard.reanderPage

            obj.currentPage = obj.currentPage-1;
            if obj.currentPage < 1
                obj.currentPage = 1;
                return
            end
            obj.renderPage(obj.currentPage)
        end %previousPage


        function closeWizard(obj,~,~)
            % This callback function runs when the window is closed. 
            % It calls the destructor, which tidies up the wizard class.
            obj.delete;
        end % closeWizard

    end % close methods


end % close classdef
