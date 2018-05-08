function planeData=obtainScanTiltPlaneMeasurements(varargin)

    % BakingTray.utils.obtainScanTiltPlaneMeasurements(varargin)
    %
    % Purpose
    % If the image plane is tilted with respect to the motion axes then we need to correct this. 
    % It can be hard to tell how tilted the plane is by eyeballing stuff, so this function performs
    % a measurement. It makes a local z-stack then translates one stage to position stuff at one edge 
    % of the image to the opposite edge. Then it takes the stack again. It repeats for the other axis. 
    % After this process is complete we can calculate the tilt.



    hBT = BakingTray.getObject;
    if isempty(hBT)
        return
    end

    if ~strcmp(class(hBT.scanner), 'SIBT')
        fprintf('Scanner must be of class SIBT\n')
        return
    end


    %Handle default input arguments
    params = inputParser;
    params.CaseSensitive=false;
    params.addParameter('depthToImage',70);
    params.addParameter('distanceBetweenDepths',0.25);
    params.addParameter('widthOfRegion',100);
    params.parse(varargin{:});

    depthToImage = params.Results.depthToImage; %Number of microns over which to obtain depth measurements
    distanceBetweenDepths = params.Results.distanceBetweenDepths; %Number of microns between adjacent optical planes
    widthOfRegion = params.Results.widthOfRegion; %Width in micros of the x/y region we will use 




    % Get useful references
    scn = hBT.scanner;
    if length(scn.channelsToAcquire)>1
        fprintf('ERROR: You should set ScanImage to acquire just one channel\n')
        return
    end

    scnSet = scn.returnScanSettings;


    % Where data will be saved
    tdir = tempdir; % Image files are stored here
    fnameBase = ['tiltPlane_',datestr(now,'yymmdd_HHMMSS')]; %All files start with this



    %Set up the Z stack parameters based on the input arguments provided
    setupZstack


    %Set up the save path, file names, etc
    scn.hC.hScan2D.logFilePath = tdir;
    scn.hC.hScan2D.logFileStem = fnameBase;
    scn.hC.hChannels.loggingEnable = true;
    scn.hC.hScan2D.logFileCounter = 1; % Start each section with the index at 1. 

    %Produce output structure, which will be needed to load the stacks afterwards and process the data



    %TODO - there is no formal link between motion axes and image axes
    motionAlongColsInMicrons = scnSet.FOV_alongColsinMicrons-widthOfRegion;
    motionAlongColsInMM = motionAlongColsInMicrons/1E3;

    motionAlongRowsInMicrons = scnSet.FOV_alongRowsinMicrons-widthOfRegion;
    motionAlongRowsInMM = motionAlongRowsInMicrons/1E3;


    %Take the Z-stack
    planeData=struct;
    takeZstack


    hBT.moveXYby(0,motionAlongRowsInMM,true);
    takeZstack

    hBT.moveXYby(motionAlongColsInMM,-motionAlongRowsInMM,true);
    takeZstack

    %Return to where we started from 
    hBT.moveXYby(-motionAlongColsInMM,0,true);



    function takeZstack
        cnter=scn.hC.hScan2D.logFileCounter;
        [x,y]=hBT.getXYpos;
        tFname = sprintf('%s_%05d.tif',scn.hC.hScan2D.logFileStem,cnter);
        tFname = fullfile(scn.hC.hScan2D.logFilePath,tFname);
        fprintf('Saving stack %d as %s\n', ...
            cnter, tFname)

        % Log data for this X/Y combo
        planeData(cnter).directory = tdir;
        planeData(cnter).fnameBase = fnameBase;
        planeData(cnter).distanceBetweenDepths = distanceBetweenDepths;
        planeData(cnter).widthOfRegion = widthOfRegion;
        planeData(cnter).pos.x = x;
        planeData(cnter).pos.y = y;

        scn.hC.startGrab 
        %Wait until acquisition has finished

        while ~strcmpi(scn.hC.acqState,'idle')
            pause(0.25)
        end
        if ~exist(tFname,'file')
            fprintf('FAILED TO FIND FILE: %s\n',tFname)
        else
            [~,planeData(cnter).imStack] = scanimage.util.opentif(tFname);
            planeData(cnter).imStack = squeeze(planeData(cnter).imStack);
            delete(tFname)
        end
    end



    function setupZstack
        % Set up for a z-stack using the parameters we have defined in the 
        % main function body.
        numDepths = round(depthToImage/distanceBetweenDepths);

        if ~strcmp(scn.hC.hFastZ.waveformType,'step') 
            scn.hC.hFastZ.waveformType = 'step'; %Always
        end
        if scn.hC.hFastZ.numVolumes ~= 1
            scn.hC.hFastZ.numVolumes=1; %Always
        end
        if scn.hC.hFastZ.enable ~=1
            scn.hC.hFastZ.enable=1;
        end
        if scn.hC.hStackManager.framesPerSlice ~= 1
            scn.hC.hStackManager.framesPerSlice = 1; %Always (number of frames per grab per layer)
        end
        if scn.hC.hStackManager.stackReturnHome ~= 1
            scn.hC.hStackManager.stackReturnHome = 1;
        end

        %The number of depths and step size
        if scn.hC.hStackManager.numSlices ~= numDepths;
            scn.hC.hStackManager.numSlices = numDepths;
        end
        if scn.hC.hStackManager.stackZStepSize ~= distanceBetweenDepths;
            scn.hC.hStackManager.stackZStepSize = distanceBetweenDepths;
        end


    end

end
