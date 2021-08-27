function buildFigure(obj)
    % Build figure window for the channel chooser

    obj.hFig = uifigure;
    obj.hFig.Tag = obj.mainGUIname;
    obj.hFig.Position = [obj.hFig.Position(1:2),1000,1000]; %hack


    %obj.hFig.MenuBar = 'none';
    %obj.hFig.ToolBar = 'none';
    %obj.hFig.Resize = 'off';
    obj.hFig.Name = 'BakingTray Channel Chooser';


    obj.hAxesMain = uiaxes(obj.hFig);
    obj.hAxesMain.Units = 'normalized';
    obj.hAxesMain.Position = [0.05,0.5,0.9,0.45];


    hold(obj.hAxesMain,'on')
    for ii=1:4 
        obj.hFilterBands(ii) = obj.plotChanBand(obj.chanRanges(ii));
    end

    %h(1) = obj.plotEmissionSpectrum('egfp');
    %h(2) = obj.plotEmissionSpectrum('mcherry');
    %h(3) = obj.plotEmissionSpectrum('ebfp');
    %h(4) = obj.plotEmissionSpectrum('alexa647');
    %h(5) = obj.plotEmissionSpectrum('DiI');

    obj.hAxesMain.XLim = [400,750];
    obj.hAxesMain.YLim = [0,1];
    obj.hAxesMain.YTick = [];
    obj.hAxesMain.Box='on';



    % Make tick boxes for each fluorophore
    obj.hPanel = uipanel('Parent', obj.hFig, ...
                     'Units', 'normalized', ...
                     'Position',[0.05,0.05,0.9,0.35],...
                     'BackgroundColor',[0.75,0.75,0.75]);
    


    y=linspace(1,300,length(obj.dyes));
    for ii = 1:length(obj.dyes)
        obj.hCheckBoxes(ii) = uicheckbox(obj.hPanel,'Text',obj.dyes{ii}, ...
            'Position',[40, y(ii),100,22], ...
            'ValueChangedFcn', @obj.dyeCallback);
    end

    obj.hMessageText = uitextarea('Parent',obj.hPanel, ...
                                'Position',[200,25,350,100]);

end




