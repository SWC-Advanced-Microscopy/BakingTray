function settings=componentSettings
    % component settings file for BakingTray
    %
    % function settings=componentSettings
    %
    % The BakingTray anatomy system controls the following hardware and software components:
    % a) three-axis stage on which the sample moves
    % b) Vibratome to cut the sample
    % c) Scanning software package that handles the image acquisition, laser power modulation,
    %    and fast objective motion for imaging multiple optical planes.
    % d) Communications with the excitation laser.
    %
    % BakingTray coordinates image acquisition and cutting using the above components.
    % This settings file defines precisely what those components are: which piece of hardware
    % does what, how to connect to the hardware, and with what parameters. e.g. which COM
    % port the laser is connected to and what are the motion limits on the linear stages.
    %
    % You should fill out the following fields carefully according to the instructions in
    % the associated comment lines. Particularly with the motion limits on the linear stages
    % it is **YOUR RESPONSIBILITY** to ensure that stages can not move too far and cause damage.
    %




    %-------------------------------------------------------------------------------------------
    % Laser
    % BakingTray communicates with the laser in order to stop acquiring if it loses modelock
    % and to turn off the laser at the end of acquisition.
    laser.type='maitai'; % One of: 'maitai', 'dummyLaser'
    laser.COM=1;  % COM port number on which the laser is attached.
    laser.pockels.doPockelsPowerControl=true;
    laser.pockels.pockelsDAQ='beam';
    laser.pockels.pockelsDigitalLine='port0/line0';



    %-------------------------------------------------------------------------------------------
    % Cutter
    % The cutter component communicates with the vibratome.
    cutter.type='FaulhaberMCDC'; % One of: 'FaulhaberMCDC', 'dummyCutter'.
    cutter.COM=6;  % COM port number on which the cutter is attached LOCATION OxMf bus, port1




    %-------------------------------------------------------------------------------------------
    % Scanner
    % Scanning is achieved using separate piece of software which BakingTray controls via an API.
    % Currently only ScanImage 5.2 is supported, although in principle you could write your own
    % scanning code. ScanImage can be freely downloaded here:
    % http://scanimage.vidriotechnologies.com/display/SIH/ScanImage+Home
    scanner.type='SIBT'; % One of: 'SIBT', 'dummyScanner'

    % The following is empty for SIBT. The first time the software is run there are additional
    % settings files made in the SETTINGS directory. These influence how the scanner behaves
    % and also set the frame sizes (microns per pixel, etc). Please edit those.
    scanner.settings = [];



    %-------------------------------------------------------------------------------------------
    % MOTION CONTROLLERS
    % The remaining sections relate to the motion controllers used to translate the sample
    % in X and Y and push it up and down in Z. To set up each motion axis you need to define
    % the properties of the physical stage responsible for motion along that axis and the
    % properties of the controller that commands the stage. For example:
    % - Most stages at least are associated with parameters that define the minimum and maximum
    %   position you wish them to move to. Some stages might have other parameters.
    % - Stage controllers will need to at least have the method of communication defined, such as
    %   a COM port or a serial number.
    % You may need to install other software to get your stages working. Read the manuals that
    % came with the stage.
    %
    % When setting up for the first time, you should initially set the motion limits to be at or
    % near the full range of the stage. Place the empty water bath on the stage, remove the objective
    % and blade holder, and confirm the stages move as expected and gauge roughly what are the limits
    % of motion along all three axes. e.g. how far can you go before you risk hitting the objective
    % with the bath. Set the motion limit parameter such that this doesn't happen. Close and re-connect
    % to the stages. Confirm they do not execute potentially dangerous motions. Add the objective and
    % blade holder and confirm. Note that, for instance, the clearance on the blade holder will vary
    % with Z position. Ensure that at no Z position will the blade holder hit the stage.
    % It is **CRITICAL** that you carefully do this in order to avoid hardware damage. Do not proceed
    % with using the software until you are convinced that the stages can not enter a configuration
    % that could cause damage. You are liable for your own hardware.



    %-------------------------------------------------------------------------------------------
    % X axis
    nC=1;
    motionAxis(nC).type='C891';
    motionAxis(nC).settings.connectAt.interface='usb';
    motionAxis(nC).settings.connectAt.ID='116010269';
    motionAxis(nC).settings.connectAt.controllerModel='C-891';

    motionAxis(nC).stage.type='genericPIstage';
    motionAxis(nC).stage.settings.invertDistance=1;
    motionAxis(nC).stage.settings.positionOffset=0;
    motionAxis(nC).stage.settings.axisName='xAxis';
    motionAxis(nC).stage.settings.minPos = -21.5;
    motionAxis(nC).stage.settings.maxPos =  65;


    %-------------------------------------------------------------------------------------------
    % Y axis
    nC=2;
    motionAxis(nC).type='C891';
    motionAxis(nC).settings.connectAt.interface='usb';
    motionAxis(nC).settings.connectAt.ID='116010268';
    motionAxis(nC).settings.connectAt.controllerModel='C-891';

    motionAxis(nC).stage.type='genericPIstage';
    motionAxis(nC).stage.settings.invertDistance=1;
    motionAxis(nC).stage.settings.positionOffset=0;
    motionAxis(nC).stage.settings.axisName='yAxis'; %Only change if you know what you are doing
    motionAxis(nC).stage.settings.minPos = -18;
    motionAxis(nC).stage.settings.maxPos = 22;

    %-------------------------------------------------------------------------------------------
    % Z axis
    nC=3;
    motionAxis(nC).type='genericZaberController';
    motionAxis(nC).settings.connectAt='COM4';

    motionAxis(nC).stage.type = 'DRV014';
    motionAxis(nC).stage.settings.invertDistance=1;
    motionAxis(nC).stage.settings.controllerUnitsInMM=1/12800; % Used for Zaber controllers with DRV014
    motionAxis(nC).stage.settings.axisName = 'zAxis'; %Only change if you know what you are doing
    motionAxis(nC).stage.settings.minPos = -0.25;
    motionAxis(nC).stage.settings.maxPos = 35.7;




    %-------------------------------------------------------------------------------------------
    % Assemble the output structure
    % -----> DO NOT EDIT BELOW THIS LINE <-----
    settings.laser      = laser  ;
    settings.cutter     = cutter ;
    settings.scanner    = scanner;
    settings.motionAxis = motionAxis;
    %-------------------------------------------------------------------------------------------

