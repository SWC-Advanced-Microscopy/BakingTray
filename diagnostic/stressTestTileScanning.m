function stressTestTileScanning
% Stress tests the tile scanning by running many tile scans in a loop
%
% function stressTestTileScanning
%
% Purpose
% Very simple code to stress-test tile scanning. See instructions, below.
%
% Inputs
% none
%
% Outputs
% none
%
% Instructions 
% There are no inputs or outputs. Please read through code comments and modify
% things as needed. Please make a copy of this file so edits are not made in the
% file located in the "diagnosic" folder. 



% Get the BakingTray API object
hBT = BakingTray.getObject;


%%
% The following structure defines the parameters of the tile scan. You can
% edit them to change the tile scan size znd location. 

% The following two parameters set the size of the tile scan in units of tiles 
% along the X and Y axes. Tile size is determined from the Fov size in ScanImage.
ROI.numTiles.X=15;
ROI.numTiles.Y=10;


% The front/left corner of the tile pattern in mm. Changing these settings will 
% translate the location of the tile scan. 
ROI.frontLeftStageMM.X=-10; 
ROI.frontLeftStageMM.Y=5;

% Do not edit these:
ROI.frontLeftPixel.X=1; 
ROI.frontLeftPixel.Y=1;


% Make the tile pattern using the above structure. The output variable
% is a series of tile locations defined in mm in X (column 1) and Y (column 2).
tilePattern = hBT.recipe.tilePattern([],[],ROI);


%% 
% The "fixedMotionTime" variable determines how the system waits before moving
% to the next position. If the following variable is >0 then the loop waits this 
% many seconds between positions. e.g. if it is 0.33 then it waits 330 ms. 
% If the variable is zero the loop waits for the controller to return that it has 
% completed the motion. i.e. the controller blocks execution until it reports it has
% reached the target location. 
% With PI stages we run with "fixedMotionTime=0" as the controllers do a good job
% of reporting that the target position has been reached. With Zaber controllers 
% this has been a bit of a problem as the controller is quite slow reporting whether 
% the motion has completed. We historically have used a fixed delay for Zaber controllers. 
% The length of this delay must be measured empirally based on the motion of the stage. 
% Perhaps a value of 0.2 or 0.3 seconds is reasonable for a lead-screw based stage. 
% Alterantively, you might want to anyway try a value of zero with a Zaber stage if
% you are debugging something related to stage motion completion times. 
fixedMotionTime=0;

%%
% Number of times to repeat the tile scan. For a thorough test you might want to set
% this to about 500. 
numTileScans = 4;


%%
% start tile scan loop
for T = 1:numTileScans
    fprintf('Starting tile scan %d/%d\n', T, numTileScans)

    for ii=1:size(tilePattern,1)
        hBT.moveXYto(tilePattern(ii,1), tilePattern(ii,2),fixedMotionTime<=0)
    
        if fixedMotionTime>0
            pause(fixedMotionTime)
        end
    
    end % ii
end % T


