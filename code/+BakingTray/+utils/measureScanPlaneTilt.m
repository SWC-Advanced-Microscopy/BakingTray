function fnames=measureScanPlaneTilt(varargin)

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
    params.addParameter('depthToImage',20);
    params.addParameter('distanceBetweenDepths',1);
    params.addParameter('widthOfRegion',100);
    params.parse(varargin{:});

    depthToImage = params.Results.depthToImage; %Number of microns over which to obtain depth measurements
    distanceBetweenDepths = params.Results.distanceBetweenDepths; %Number of microns between adjacent optical planes
    widthOfRegion = params.Results.widthOfRegion; %Width in micros of the x/y region we will use 




    % Get useful references
    scn = hBT.scanner;
    scnSet = scn.returnScanSettings;


    % Where data will be saved
    tdir = tempdir; % Image files are stored here
    fnameBase = ['tiltPlane_',datestr(now,'yymmdd_HHMMSS')]; %All files start with this



    %Set up the Z stack parameters based on the input arguments provided
    setupZstack


    %Set up the save path, file names, etc
    scn.hScan2D.logFilePath = tdir;
    scn.hScan2D.logFileStem = fnameBase;
    scn.hChannels.loggingEnable = true;
    scn.hScan2D.logFileCounter = 1; % Start each section with the index at 1. 

    %Produce output structure, which will be needed to load the stacks afterwards and process the data
    fnames.directory = tdir;
    fnames.fnameBase = fnameBase;



    %TODO - there is no formal link between motion axes and image axes


    %Take the Z-stack
    takeZstack


    hBT.moveXYby(0,motionAlongRowsInMicrons,true);
    takeZstack

    hBT.moveXYby(motionAlongColsInMicrons,-motionAlongRowsInMicrons,true);
    takeZstack

    %Return to where we started from 
    hBT.moveXYby(-motionAlongColsInMicrons,0,true);



    function takeZstack
        fprintf('Saving stack %d as %s\n')
        scn.startGrab %Or whatever
    end



    function setupZstack
        % Set up for a z-stack using the parameters we have defined in the 
        % main function body.
        numDepths = round(depthToImage/distanceBetweenDepths);

        motionAlongColsInMicrons = scnSet.FOV_alongColsinMicrons-widthOfRegion;
        motionAlongColsInMM = motionAlongColsInMicrons/1E3;

        motionAlongRowsInMicrons = scnSet.FOV_alongRowsinMicrons-widthOfRegion;
        motionAlongRowsInMM = motionAlongRowsInMicrons/1E3;

        if ~strcmp(scn.hFastZ.waveformType,'step') 
            scn.hFastZ.waveformType = 'step'; %Always
        end
        if scn.hFastZ.numVolumes ~= 1
            scn.hFastZ.numVolumes=1; %Always
        end
        if scn.hFastZ.enable ~=1
            scn.hFastZ.enable=1;
        end
        if scn.hStackManager.framesPerSlice ~= 1
            scn.hStackManager.framesPerSlice = 1; %Always (number of frames per grab per layer)
        end
        if scn.hStackManager.stackReturnHome ~= 1
            scn.hStackManager.stackReturnHome = 1;
        end

        %The number of depths and step size
        if scn.hStackManager.numSlices ~= numDepths;
            scn.hStackManager.numSlices = numDepths;
        end
        if scn.hStackManager.stackZStepSize ~= distanceBetweenDepths;
            scn.hStackManager.stackZStepSize = distanceBetweenDepths;
        end


    end

end
