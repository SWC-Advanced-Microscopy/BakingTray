function varargout=focusNamedFig(figTagName)
	% mxy.focusNamedFig(figTagName)
	%
	% Purpose
	% Brings to focus the figure with the tag name 'figTagName'
	% Creates the figure if it does not exist
	%
	% 

	if nargin<1 || isempty(figTagName)
		fprintf('%s expects one input argument\n',mfilename)
		return
	end

	if ~ischar(figTagName)
		fprintf('%s expects figTagName to be a character array\n',mfilename)
		return
	end

	f=findobj('tag',figTagName);

    if isempty(f)
        hFig=figure;
        hFig.Tag=figTagName;
    else
        hFig=f;
	end
    
    figure(hFig) %bring to focus
    if nargout>0
    	varargout{1}=hFig;
    end

end