classdef child_view < handle
    % All views that are "children" (attached views) of BakingTray.gui.view inherit this class

    properties(Hidden)
        hFig         % The figure window handle 
        fSize=12     % Default font size
        model        % The model controlled by the view. Could be an instance of BT or an instance of the hardware component (e.g. laser)
        listeners={} % Handles to listeners stored here in order to delete them when GUI closes
    end %properties

    properties (Hidden,Transient)
        parentView=[]; %This is the main view to which the acquire GUI is attached. It is present so it can be disabled and enabled.
    end %close hidden transient properties

    methods

        function obj=child_view
            if ispc
                obj.fSize=9;
            end
        end

        function delete(obj)
            obj.model=[]; % We absolutely don't want to close down the model/component just by closing the view. 
            obj.parentView=[]; %ditto

            delete(obj.hFig);
            cellfun(@delete,obj.listeners)
        end

         %Figure close method
         function closeComponentView(obj,~,~)
            obj.delete;
         end

    end %methods
end % child_view


