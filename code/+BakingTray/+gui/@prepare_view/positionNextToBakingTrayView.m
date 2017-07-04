function positionNextToBakingTrayView(obj)
    % Position the prepare window next to the main BakingTray window when it opens
    %
    % function BT.positionNextToBakingTrayView(obj)

    if isempty(obj.hBTview)
        %Then the GUI wasn't started by pressing the button on the main BT view
        return
    end
    %Place the GUI to the left or right of the main BakingTray view, depending on 
    %the current position of the BakingTray view on the screen. 
    BTpos=obj.hBTview.hFig.Position; %BakingTray main view window size
    hSize=obj.hFig.Position; %Prepare view window size
    screenSize=get(0,'ScreenSize');

    if ispc
        offset=15;
    else
        offset=0;
    end

    %Is there room to the right?
    if BTpos(1)+BTpos(3)+hSize(3) < screenSize(3)
        obj.hFig.Position(1)=BTpos(1)+BTpos(3)+offset;
    else %Otherwise we place on the left
        obj.hFig.Position(1)=BTpos(1)-hSize(3)-offset;
    end
    obj.hFig.Position(2)=BTpos(2);
end %positionNextToBakingTrayView