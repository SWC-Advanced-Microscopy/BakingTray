function displayMessage(obj,~,~)
    % Callback that displays to a warning dialog box the contents of BT.messageString
    %
    % Purpose
    % General-purpose message display for BakingTray GUI. Displays
    % BT.messageString whenever that string is changed and is not empty.
    % This system does not have to be used for all messages. fprintf
    % directly from methods of BT is also fine. However, this method
    % provides greater flexibility.
    %
    % See also main BT class properties.

    if isempty(obj.model.messageString)
        return
    end

    warndlg(obj.model.messageString,'')
