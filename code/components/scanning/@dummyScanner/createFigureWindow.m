function createFigureWindow(obj,~,~)
% Create a figure window into which we will place images
f=findobj('Tag','CurrentDummyImFig');
if ~isempty(f) && isvalid(f)
    return
end

    obj.hCurrentImFig = figure;
    set(obj.hCurrentImFig, ...
        'Tag','CurrentDummyImFig', ...
        'Name', 'DUMMY SCANNER', ...
        'CloseRequestFcn',@obj.figCloseFcn);

    obj.hCurrentImFig.Position(3)=750;
    obj.hCurrentImFig.Position(4)=920;

    % Modify to suit our needs
    set(obj.hCurrentImFig,'color',[1,0.9,0.9]*0.1)

    % Menus
    allhandles = findall(obj.hCurrentImFig);
    menuhandles = findobj(allhandles,'type','uimenu');
    delete(findobj(menuhandles,'tag','figMenuHelp'));

    obj.scannerMenu = uimenu(obj.hCurrentImFig,'Label','Scanner');

    obj.acquireTileMenu = uimenu(obj.scannerMenu,'label', 'Acquire Tile', ...
                'Callback', @obj.acquireTile);

    obj.focusStartStopMenu = uimenu(obj.scannerMenu,'label', 'Start Focus', ...
                'Callback', @obj.startFocus);

    % Create two sub-plots. One will show the whole section, the other the current frame
    obj.hWholeSectionAx = axes('Position',[0.025,0.45,0.95,0.5]);
    obj.hWholeSectionPlt = imagesc(ones(100,250));
    obj.hWholeSectionPlt.Tag='sectionImage';
    hold on
    obj.hTileLocationBox = plot(nan,nan,'x-r','LineWidth',2,'MarkerSize',15);
    hold off
    axis equal off

    obj.hCurrentFrameAx = axes('Position',[0.275,0.01,0.45,0.45]);
    obj.hCurrentFramePlt = imagesc(ones(50));
    obj.hCurrentFramePlt.Tag='tileImage';
    axis equal off

    colormap gray
