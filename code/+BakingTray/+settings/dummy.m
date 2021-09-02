function settings=componentSettings_dummy
    % dummy component settings file for BakingTray
    %
    % function settings=componentSettings_dummy
    %
    % This settings file sets up the dummy stages, laser, and scanner to allow
    % for testing the BakingTray system without hardware present. 

    %-------------------------------------------------------------------------------------------
    % Laser
    laser.type='dummyLaser';
    laser.COM=[];

    %-------------------------------------------------------------------------------------------
    % Cutter
    cutter.type='dummyCutter';
    cutter.COM=[];

    %-------------------------------------------------------------------------------------------
    % Scanner
    scanner.type='dummyScanner'; 
    scanner.settings=[]; 

    %-------------------------------------------------------------------------------------------
    % Motion axes definitions

    % X
    nC=1;
    motionAxis(nC).type='dummy_linearcontroller';
    motionAxis(nC).settings.connectAt='';
    nS=1;
    motionAxis(nC).stage(nS).type='dummy_linearstage'; 
    motionAxis(nC).stage(nS).settings.invertDistance=1;
    motionAxis(nC).stage(nS).settings.axisName='xAxis';
    motionAxis(nC).stage(nS).settings.minPos=-25;
    motionAxis(nC).stage(nS).settings.maxPos=30;

    % Y
    nC=2;
    motionAxis(nC).type='dummy_linearcontroller';
    motionAxis(nC).settings.connectAt='';
    nS=1;
    motionAxis(nC).stage(nS).type='dummy_linearstage'; 
    motionAxis(nC).stage(nS).settings.invertDistance=1;
    motionAxis(nC).stage(nS).settings.axisName='yAxis'; 
    motionAxis(nC).stage(nS).settings.minPos=-25;
    motionAxis(nC).stage(nS).settings.maxPos=25;

    % Z
    nC=3;
    motionAxis(nC).type='dummy_linearcontroller';
    motionAxis(nC).settings.connectAt=[];
    nS=1;
    motionAxis(nC).stage(nS).type='dummy_linearstage';
    motionAxis(nC).stage(nS).settings.invertDistance=1;
    motionAxis(nC).stage(nS).settings.axisName='zAxis';
    motionAxis(nC).stage(nS).settings.minPos=0;
    motionAxis(nC).stage(nS).settings.maxPos=50;



    %-------------------------------------------------------------------------------------------
    % Assemble the output structure
    % -----> DO NOT EDIT BELOW THIS LINE <-----
    settings.laser      = laser  ;
    settings.cutter     = cutter ;
    settings.scanner    = scanner;
    settings.motionAxis = motionAxis;
    %-------------------------------------------------------------------------------------------

