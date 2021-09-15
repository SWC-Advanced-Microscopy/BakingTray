function centerFigureInScreen(figHandle)
	% BakingTray.utils.centerFigureInScreen(figHandle)
	%
	% Purpose
	% Centres window figHandle in the middle of the screen
	%
	%



	% Screen size of the primary display
	monitorSize = get(0,'ScreenSize');


	figSize = get(figHandle,'Position');


	% Set the corner loction
	figHandle.Position(1) = (monitorSize(3)/2) - (figSize(3)/2);
	figHandle.Position(2) = (monitorSize(4)/2) - (figSize(4)/2);