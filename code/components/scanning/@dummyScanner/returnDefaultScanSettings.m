function OUT = returnDefaultScanSettings(obj)
    %Where needed, the following settings are modified
    %when attachPreviewStack runs. 
    OUT.pixelsPerLine=512;
    OUT.linesPerFrame=512;
    OUT.micronsBetweenOpticalPlanes=10;

    OUT.FOV_alongColsinMicrons=775;
    OUT.FOV_alongRowsinMicrons=775;

    OUT.micronsPerPixel_cols=OUT.FOV_alongColsinMicrons/OUT.pixelsPerLine;
    OUT.micronsPerPixel_rows=OUT.FOV_alongRowsinMicrons/OUT.linesPerFrame;

    OUT.framePeriodInSeconds = 0.5;
    OUT.pixelTimeInMicroSeconds = (OUT.framePeriodInSeconds * 1E6) / (OUT.pixelsPerLine * OUT.linesPerFrame);
    OUT.linePeriodInMicroseconds = OUT.pixelTimeInMicroSeconds * OUT.pixelsPerLine;
    OUT.bidirectionalScan = true;
    OUT.activeChannels = 1:4;
    OUT.beamPower= 10; %percent
    OUT.scannerType='simulated';
    OUT.scannerID=obj.scannerID;
    OUT.slowMult = 1;
    OUT.fastMult = 1;
    OUT.zoomFactor =1;
    OUT.numOpticalSlices=obj.numOpticalPlanes;
    OUT.averageEveryNframes=obj.averageEveryNframes;
end