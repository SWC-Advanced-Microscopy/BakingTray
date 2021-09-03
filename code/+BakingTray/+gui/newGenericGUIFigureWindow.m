function H = newGenericGUIFigureWindow(tagName,keepDecorations,isUIfigure)
% Build new generic GUI window for a BakingTrayGUI
%
% function H = newGenericGUIFigureWindow(tagName,keepDecorations,isUIfigure)
%
% Purpose
% Creates a new figure bearing tag "tagName" or, if this exists,
% return the handle to this figure and brings this window into
% focus. Returns empty if the figure already exists.
%
% Inputs
% tagName - String that will be assigned as the figure's Tag property
% keepDecorations - Optional bool. False by default. If true the toolbar
%                   and the menubar are retained. 
% isUIfigure - Optional bool. False by default. If true the the window will be
%              a uifigure instead of regular figure. 
%
%


if nargin<2 || isempty(keepDecorations)
    keepDecorations=false;
end

if nargin<3
    isUIfigure=false;
end

% Return existing handle if possible
f = findobj('Tag', tagName);
if ~isempty(f)
    figure(f)
    H=[];
    return
end

% Otherwise make a new figure and assign the tag a value of "tagName"

if isUIfigure
    H = uifigure;
else
    H = figure;
    H.HandleVisibility = 'callback'; %so it doesn't respond to "close all"
end

H.Tag = tagName;
H.Resize = 'Off';
H.Units = 'Pixels';
H.NumberTitle = 'off';


if ~keepDecorations
    set(H, ...
        'ToolBar', 'none', ...
        'MenuBar', 'none')
end

set(H,'Color', [1,1,1]*0.15);
