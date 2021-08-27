function a = plotChanBand(obj,chan)

    % Plot channel band in main figure. 
    minL = chan.centre - (chan.width/2);
    maxL = chan.centre + (chan.width/2);


    r = BakingTray.utils.wavelength2rgb(chan.centre);

    a=area(obj.hAxesMain,[minL,minL,maxL,maxL],[0,1.1,1.1,0]);
    a.FaceColor=r.light;
    a.EdgeColor=r.dark;
end

