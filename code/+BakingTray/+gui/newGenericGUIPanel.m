function thisPanel = newGenericGUIPanel(Position,parentObj)
% function thisPanel = newGenericGUIPanel(Position,parentObj)
%
% 

if ~isnumeric(Position)
    fprintf('ERROR: Input argument "Position" in function %s should be numeric\n', mfilename)
    return
end

if ~isvector(Position)
    fprintf('ERROR: Input argument "Position" in function %s should be a vector\n', mfilename)
    return
end

if length(Position)~=4
    fprintf('ERROR: Input argument "Position" in function %s should be a vector of length 4\n', mfilename)
    return
end


thisPanel = uipanel(...
    'Parent', parentObj,...
    'Units', 'pixels', ...
    'Position', Position,...
    'BackgroundColor', [1,1,1]*0.075,...
    'HighlightColor', [0.5020 0.5020 0.5020],...
    'ShadowColor', [0.3137 0.3137 0.3137]);