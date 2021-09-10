function startChannelChooserGUI(obj,~,~)

    if isempty(obj.view_channelChooser) || ~isvalid(obj.view_channelChooser)
        obj.view_channelChooser=BakingTray.channelChooser(obj.model,obj);
    else
        figure(obj.view_channelChooser.hFig)
    end
end
