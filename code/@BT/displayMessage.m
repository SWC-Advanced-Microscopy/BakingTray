function displayMessage(obj,~,~)
    % Callback that displays to the CLI the contents of BT.messageString
    %
    % Purpose
    % General-purpose message display for BakingTray. Displays
    % BT.messageString whenever that string is changed and is not empty.
    % This system does not have to be used for all messages. fprintf
    % directly from methods of BT is also fine. However, this method
    % provides greater flexibility and also allows messages to be broadcast
    % the view class and displayed as a warning dialog. That class too
    % monitors BT.messageString...

    if isempty(obj.messageString)
        return
    end


    fprintf(obj.messageString)
    
    if ~endsWith(obj.messageString,'\n')
        fprintf('\n')
    end
