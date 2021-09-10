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


    % Add the emission filter bands as colored areas

    hold(obj.hAxesMain,'on')
    for ii=1:length(obj.chanRanges)
        obj.hFilterBands(ii) = obj.plotChanBand(obj.chanRanges(ii));
    end

    obj.hAxesMain.XLim = [400,720];
    obj.hAxesMain.YLim = [0,1];
    obj.hAxesMain.YTick = [];
    obj.hAxesMain.Box='on';


    % Create a panel into which we will place the user interaction
    % elements such as fluorophore checkboxes. 
    obj.hPanel = uipanel('Parent', obj.hFig, ...
                     'Position',[5, 5, 880,400],...
                     'BackgroundColor',[0.75,0.75,0.75]);
    

    % Make tick boxes for each fluorophore
    y=linspace(30,300,length(obj.dyes));
    for ii = 1:length(obj.dyes)
        obj.hCheckBoxes(ii) = uicheckbox(obj.hPanel,'Text',obj.dyes{ii}, ...
            'Position',[40, y(ii),100,22], ...
            'ValueChangedFcn', @obj.dyeCallback);
    end

    % The smaller axis that shows the excitation spectra and 2p cross sections
    obj.hAxesExcite = uiaxes(obj.hPanel);
    obj.hAxesExcite.BackgroundColor = obj.hPanel.BackgroundColor;
    obj.hAxesExcite.Position = [150,90,700,300];
    obj.hAxesExcite.XLim=[760,980];
    obj.hAxesExcite.TickLength=[0,0];
    obj.hAxesExcite.XLabel.String='Excitation Wavelength (nm)';
    obj.hAxesExcite.YLabel.String='2-Photon Brightness';
    hold(obj.hAxesExcite,'on')
    obj.hAxesExcite.XGrid='on';

    % Legend
    obj.hLegend = legend(obj.hAxesExcite);
    obj.hLegend.Box='off';
    obj.hLegend.Location='northwest'; 


    % Text box for reporting to screen
    obj.hMessageText = uitextarea('Parent',obj.hPanel, ...
                                'Position',[150,8,450,50]);

    % Button for setting laser
    obj.hLaserSetButton = uibutton('Parent',obj.hPanel, ...
                        'Text','Set Laser Wavelength', ...
                        'Position',[620,38,170,20], ...
                        'ButtonPushedFcn',@obj.setLaserWavelengthCallback);

    obj.hChannelSetButton = uibutton('Parent',obj.hPanel, ...
                        'Text','Set Channels To Acquire', ...
                        'Position',[620,10,170,20],...
                        'ButtonPushedFcn',@obj.setChannelsToAcquire);
    
    if isempty(obj.parentView)
        obj.hLaserSetButton.Enable='off';
        obj.hChannelSetButton.Enable='off';
    end
end




