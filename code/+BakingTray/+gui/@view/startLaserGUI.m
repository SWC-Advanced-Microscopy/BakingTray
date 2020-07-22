function startLaserGUI(obj,~,~)
    % Start the laser GUI

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
