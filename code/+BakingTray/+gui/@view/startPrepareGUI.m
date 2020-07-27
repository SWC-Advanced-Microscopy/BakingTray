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
