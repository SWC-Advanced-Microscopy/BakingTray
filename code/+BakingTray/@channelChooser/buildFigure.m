function buildFigure(obj)
    % Build figure window for the channel chooser

    obj.hFig = BakingTray.gui.newGenericGUIFigureWindow(obj.mainGUIname,false,true);

    obj.hFig.Tag = obj.mainGUIname;
    obj.hFig.Position = [obj.hFig.Position(1:2),900,800]; %hack


    %obj.hFig.MenuBar = 'none';
    %obj.hFig.ToolBar = 'none';
    %obj.hFig.Resize = 'off';
    obj.hFig.Name = 'BakingTray Channel Chooser';

    % The main axes that show the emission spectra and filter bands
    obj.hAxesMain = uiaxes(obj.hFig);
    obj.hAxesMain.Position = [15,420,875,365];
    obj.hAxesMain.Color = obj.hAxesMain.BackgroundColor;
    obj.hAxesMain.XLabel.String='Emission Wavelength (nm)';
    obj.hAxesMain.TickLength=[0,0];

    % Make whole thing gray
    obj.hFig.Color = obj.hAxesMain.BackgroundColor;



    hold(obj.hAxesMain,'on')
    for ii=1:4 
        obj.hFilterBands(ii) = obj.plotChanBand(obj.chanRanges(ii));
    end

    %h(1) = obj.plotEmissionSpectrum('egfp');
    %h(2) = obj.plotEmissionSpectrum('mcherry');
    %h(3) = obj.plotEmissionSpectrum('ebfp');
    %h(4) = obj.plotEmissionSpectrum('alexa647');
    %h(5) = obj.plotEmissionSpectrum('DiI');

    obj.hAxesMain.XLim = [400,720];
    obj.hAxesMain.YLim = [0,1];
    obj.hAxesMain.YTick = [];
    obj.hAxesMain.Box='on';


    % Make tick boxes for each fluorophore
    obj.hPanel = uipanel('Parent', obj.hFig, ...
                     'Position',[5, 5, 880,400],...
                     'BackgroundColor',[0.75,0.75,0.75]);
    


    y=linspace(1,300,length(obj.dyes));
    for ii = 1:length(obj.dyes)
        obj.hCheckBoxes(ii) = uicheckbox(obj.hPanel,'Text',obj.dyes{ii}, ...
            'Position',[40, y(ii),100,22], ...
            'ValueChangedFcn', @obj.dyeCallback);
    end

    obj.hMessageText = uitextarea('Parent',obj.hPanel, ...
                                'Position',[150,8,700,50]);

    % The smaller axis that shows the excitation spectra and 2p cross sections
    obj.hAxesExcite = uiaxes(obj.hPanel);
    obj.hAxesExcite.BackgroundColor = obj.hPanel.BackgroundColor;
    obj.hAxesExcite.Position = [150,90,700,300];
    obj.hAxesExcite.XLim=[760,950];
    obj.hAxesExcite.TickLength=[0,0];
    obj.hAxesExcite.XLabel.String='Excitation Wavelength (nm)';
    hold(obj.hAxesExcite,'on')
    obj.hAxesExcite.XGrid='on';

    % Legend
    obj.hLegend = legend(obj.hAxesExcite);
    obj.hLegend.Box='off';
    obj.hLegend.Location='northwest'; 

end




