# Stage Motion Times

This folder contains code related to timing stage motions. 
This can be used for debugging if you are concerned that your stages are moving too slowly, not enough time is being allocated to allowing them to settle, etc. 

## Before starting

Before running any code related to stage timing you should quit and restart MATLAB. 
On a minority of rigs it has been observed that, over time, MATLAB/ScanImage/BakingTray, begins to slow down by factor of 2 or 3 and restarting MATLAB solves this. 

For more accurate values you should have the stages assembled as an X/Y pair and a water bath filled to the typical level placed on top.

It is also a good idea with PI stages to first test how long it takes for a step and settle motion in PI MikroMove. 
You can generate graphs showing things like position over time, position error over time, etc. 
This provides a really solid baseline indicating what to expect. 

Once you are ready: start BakingTray at the MATLAB command line. 



## Quick test of stage motion times
Run `softwareTimedMotionTime.m` then make plots of the resulting output. 
Read through the code before running the function! 
You can edit variables in-line to change behavior.
It is recommended to copy file to a new location to do this, otherwise you will have to revert changes before pulling the latest version of BakingTray when you want to update. 

## Checking motion times in a tile scan
You can start a tile scan in BakingTray without having to turn on the laser, the PMTs, make a directory, etc. 
To do this:

1. Open the Prepare Sample window
2. Open the Preview window
3. Hit "ROI" and draw a box in the area you want to tile scan
4. Select "tiled: manual ROI" under "Scan Mode" in the main BakingTray window
5. run `hBT.scanner.armScanner` to set up ScanImage for the tile scan
6. run `hBT.runTileScan` to initiate and run the tile scan. You might need to press "Abort" in ScanImage to do more tile scans or disarm the scanner (below).
7. run `hBT.scanner.disarmScanner` after the tile scan is finished and if you plan to do no more. 

You can, for example, acquire the Y galvo signal to see how long it takes for each stage motion to complete. 
You might want to set the number of Z planes to 1 for this. 
The easiest way to decrease the step size of the stages should you need to, is to increase the zoom number in ScanImage.


## Acquiring data from a tile scan 
The `sitools.ai_recorder` class can be used to pull in data from an AI line while ScanImage runs. 
Clone from https://github.com/BaselLaserMouse/ScanImageTools and read the docs. 
It should be compatible with both the vDAQ and an NI DAQ. 
T the Y galvo waveform into an AI line that is free and set up the AI recorder to acquire this. 
You can either edit the class file, or instantiate the class and modify properties at the CLI. 
To save data, check the Save checkbox in ScanImage and choose a directory to which data are to be saved. 
Then run the tile scan as above. 
The recorder will keep saving data to disk until you hit Abort in ScanImage. 
You can use `readAIrecoderBinFile` to read data for analysis;

You can find the interval between frames using MATLAB's findpeaks function:
```matlab
findpeaks(yData) % check visually if it looks right
[pks,loc]=findpeaks(yData);
plot(lok,pks,'.')
%Then apply a threshold and get the times. e.g.
timesOfPeaks = loc(pks>0);

% Divide by the sample rate to get time in seconds
timesInSec = timesOfPeaks / 1000; % in this case data were acquired at 1kHz
plot(diff(peakTimes))

``` 