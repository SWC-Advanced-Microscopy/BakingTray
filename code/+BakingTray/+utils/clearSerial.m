function clearSerial(portName,deleteClosed)
    % Close and delete open serial ports
    %
    % function BakingTray.utils.clearSerial(portName,deleteClosed)
    %
    % Purpose
    % Deletes closed serial ports with any name (optional)
	% Close and delete all ports with name "portName"
    %
    %
    % Inputs
    % portName - [optional] a string defining which ports to close.
    %            e.g. 'COM12'. If missing, all open serial ports are
    %            closed. 
    % deleteClosed - [false by default]. If true, all  closed ports
    %                are deleted. Open ports are left untouched. 
    %
    %
    % Examples
    % >> BakingTray.utils.clearSerial
    % >> BakingTray.utils.clearSerial('COM2')
    % >> BakingTray.utils.clearSerial([],true
    %
    % 
    % Rob Campbell - Basel, 2016

	if ~ischar(portName) || isempty(regexp(portName,'COM\d+','ONCE'))
		return
	end

	if nargin<2
		deleteClosed=false;
	end


	S=instrfind('Type','serial');

	if isempty(S)
		return
	end

	for ii=length(S):-1:1
		if strcmp(get(S(ii),'Status'),'closed') && deleteClosed
			delete(S(ii))
			continue
		end

		if ~strcmp(get(S(ii),'Port'),portName)
			continue
		else
			fclose(S(ii));
			delete(S(ii));
		end


	end