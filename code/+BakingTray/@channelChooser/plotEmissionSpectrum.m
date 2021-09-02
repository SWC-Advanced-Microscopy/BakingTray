function h = plotEmissionSpectrum(obj,dye)
    % Plot emission spectrum and return handle to plot object



    data = BakingTray.channelChooser.loadEmissionSpectrum(dye);


    h = plot(data(:,1),data(:,2),'-', ...
        'Parent',obj.hAxesMain, ...
        'LineWidth',2);

    [~,ind] = max(data(:,2));


    peakL = data(ind,1);
    r = BakingTray.utils.wavelength2rgb(peakL);

    h.Color = r.regular;


    %text(peakL,peakL],[0.9,0.9], ...
    %    sprintf('%s (%d nm)', dye,peakL), ...
    %    'Parent',obj.hAxesMain)
