function stressTestTileScanning
% Stress tests the tile scanning by running many tile scans in a loop
%
% Super simple code. 
% To run with different parameters, please make a copy of this file
% to a location outside of the BakingTray path and edit that.


% Get the BakingTray API object
hBT = BakingTray.getObject;



% Set up a tile pattern with the following parameters
ROI.numTiles.X=15; %Number of tiles across in X
ROI.numTiles.Y=10;

% The front/left corner of the tile pattern in mm
ROI.frontLeftStageMM.X=-10; 
ROI.frontLeftStageMM.Y=5;

ROI.frontLeftPixel.X=1; %No need to edit
ROI.frontLeftPixel.Y=1; %No need to edit


tilePattern = hBT.recipe.tilePattern([],[],ROI);


%Fixed wait between motions. If the following variable is >0 then
%the loop waits this many seconds between positions. If the variable
%is zero, then a blocking motion is performed. i.e. the loop waits for
%the controller to return that it has completed the motion
fixedMotionTime=0;


%Number of times to repeat the tile scan
numTileScans = 4;

for T = 1:numTileScans
    fprintf('Starting tile scan %d/%d\n', T, numTileScans)

    for ii=1:size(tilePattern,1)
        hBT.moveXYto(tilePattern(ii,1), tilePattern(ii,2),fixedMotionTime<=0)
    
        if fixedMotionTime>0
            pause(fixedMotionTime)
        end
    
    end % ii
end % T


