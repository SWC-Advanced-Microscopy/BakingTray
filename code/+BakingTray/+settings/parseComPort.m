function COMPORT = parseComPort(comport)
% Returns a valid COM port string irrespective of the input
%
% function COMPORT = parseComPort(comport)
%
%
% Purpose
% Produces the string in the format 'COMx' (e.g. 'COM2') from inputs that could be 
% something else. e.g. 2, '2', 'com2', 
%
% 
% Input
% comport - the com port ID
%
% Output
% COMPORT - standardised output as described above
%
%
% Examples
%
% >> BakingTray.settings.parseComPort(1)
% ans =
% COM1
%
% >> BakingTray.settings.parseComPort('1')
% ans =
% COM1
%
% >> BakingTray.settings.parseComPort('sdfds1')
% ans =
% COM1
%
% >> BakingTray.settings.parseComPort({})
% COM port is being defined with a cell. Should be an integer.
% ans =
%     []
%
%
% Rob Campbell - Basel 2017


if isnumeric(comport)

	COMPORT = sprintf('COM%d',comport);

elseif ischar(comport)

	matchedNumbers=regexp(comport,'\d+','match');
	if length(matchedNumbers)~=1
		fprintf('%s does not appear to be a valid COM port string\n', comport)
		COMPORT=[];
		return
	end
	COMPORT = sprintf('COM%s',matchedNumbers{1});

else

	fprintf('COM port is being defined with a %s. Should be an integer.\n',class(comport))
	COMPORT=[];
	return

end

