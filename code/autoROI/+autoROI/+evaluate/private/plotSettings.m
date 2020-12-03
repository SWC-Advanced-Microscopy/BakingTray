function pltSettings = plotSettings
    % Defines common style elements so all plotting functions
    % share the same look.


    pltSettings.basePlotStyle = {'.-','color',[0.5,0.8,0.5],'markersize',9};
    pltSettings.highlightProblemCases = {'or','markersize',7,'MarkerFaceColor',[0.5,0.8,0.5]};
    pltSettings.highlightHighCoverage = {'og','markersize',7,'MarkerFaceColor',[0.5,0.8,0.5]};