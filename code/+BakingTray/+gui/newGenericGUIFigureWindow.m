function H = newGenericGUIFigureWindow(tagName,keepDecorations)
% Build new generic GUI window for a BakingTrayGUI
%
% function H = newGenericGUIFigureWindow(tagName,keepDecorations)
%
% Purpose
% Creates a new figure bearing tag "tagName" or, if this exists,
% return the handle to this figure and brings this window into
% focus. Returns empty if the figure already exists.


if nargin<2
    keepDecorations=false;
end


% Return existing handle if possible
f = findobj('Tag', tagName);
if ~isempty(f)
    figure(f)
    H=[];
    return
end

% Otherwise make a new figure and assign the tag a value of "tagName"
H = figure;
    set(H, ...
        'Tag', tagName,...
        'Resize','Off', ...
        'Units','Pixels',...
        'HandleVisibility', 'callback', ... %so it doesn't respond to "close all"
        'NumberTitle','off');

if ~keepDecorations
    set(H, ...
        'ToolBar', 'none', ...
        'MenuBar', 'none')
end

set(H,'Color', [1,1,1]*0.15);
