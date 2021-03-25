classdef messageWindow < handle
    % This class sisplays a message string in a new window.
    %
    % function h = messageWindow(messageString,title)
    %
    % Purpose
    % Pops up a new empty figure window and within it prints the string
    % "messageString". The handles are returned to allow caller code to
    % close the window or alter the string.
    %
    % Inputs
    % messageString - a string (formatted with sprintf if needed) to display
    % title - optional string providing a title to the window. none by default.
    %
    % Once created, the text can be altered using the writeMessage method
    %
    % e.g.
    % >> m=BakingTray.utils.messageWindow('HELLO HELLO')
    % >> m.writeMessage('HI THERE')
    % >> delete(m) % To close the window
    %
    %
    % Rob Campbell - SWC 2021


    properties
        hWin
        hText
    end


    methods

        function obj=messageWindow(displayString, title)
            if nargin<2 || isempty(title)
                title='';
            end

            obj.hWin=dialog;

            % Make it impossible for the user to close the window
            obj.hWin.CloseRequestFcn=[];

            obj.hText = uicontrol(...
                'Style', 'text', ...
                'Parent', obj.hWin, ...
                'Units', 'normalized', ...
                'Position', [0.2 0.4 0.6 0.2], ...
                'String', displayString, ...
                'FontSize', 18);

           obj.hWin.Name=title;
           obj.hWin.Position(4)=obj.hWin.Position(4)/2;
        end % Constructor


        function delete(obj)
            delete(obj.hWin)
        end % Destructor

        function writeMessage(obj,displayString)
            % Update the displayed text with the string "displayString"
            obj.hText.String = displayString;
        end % writeMessage

    end

end
