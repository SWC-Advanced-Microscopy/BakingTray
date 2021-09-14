function positionNextToBakingTrayView(obj)
    % Position the prepare window next to the main BakingTray window when it opens
    %
    % function BT.positionNextToBakingTrayView(obj)

    if isempty(obj.parentView)
        %Then the GUI wasn't started by pressing the button on the main BT view
        return
    end

    iptwindowalign(obj.parentView.hFig, 'right', obj.hFig, 'left');

end %positionNextToBakingTrayView
