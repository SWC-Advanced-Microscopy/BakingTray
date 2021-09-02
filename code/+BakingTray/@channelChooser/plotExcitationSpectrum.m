function h = plotExcitationSpectrum(obj,dye)
    % Plot emission spectrum and return handle to plot object



    data = BakingTray.channelChooser.loadExcitationSpectrum(dye);

    if isempty(data)
        h = [];
        return
    end

    h = plot(data(:,1),data(:,3),'-', ...
        'Parent',obj.hAxesExcite, ...
        'LineWidth',2);

    [~,ind] = max(data(:,2));


    peakL = data(ind,1);
    r = BakingTray.utils.wavelength2rgb(peakL);

    h.Color = r.regular;


    %text(peakL,peakL],[0.9,0.9], ...
    %    sprintf('%s (%d nm)', dye,peakL), ...
    %    'Parent',obj.hAxesExcite)
