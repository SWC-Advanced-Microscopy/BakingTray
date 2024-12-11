function out = softwareTimedMotionTime
% Perform a bunch of blocking relative motions in X and Y and see how long they take
% 
% Inputs
% none
%
% Outputs
% A structure containing motion times in seconds
%
% Rob Campbell - SWC, 2024

hBT = BakingTray.getObject;

moveBySize = 1;
nMotions = 100;

xTimes = zeros(1,nMotions);

fprintf('Doing X motions')
for ii=1:nMotions
	tic
	hBT.moveXYby(moveBySize,0,true);
	moveBySize = moveBySize*-1; % so next mostion is the other way
	xTimes(ii)=toc;


	if mod(ii,2) == 0
		fprintf('.')
	end

	pause(0.5); % Because in practice we never rock and back forth with no delay
end

fprintf('\n')

out.xMotionTimes = xTimes;




yTimes = zeros(1,nMotions);

fprintf('Doing Y motions')
for ii=1:nMotions
	tic
	hBT.moveXYby(0,moveBySize,true);
	moveBySize = moveBySize*-1; % so next mostion is the other way
	yTimes(ii)=toc;

	if mod(ii,2) == 0
		fprintf('.')
	end

	pause(0.5); % Because in practice we never rock and back forth with no delay
end

fprintf('\n')



% Build output structure
out.xMotionTimes = xTimes;
out.yMotionTimes = yTimes;







