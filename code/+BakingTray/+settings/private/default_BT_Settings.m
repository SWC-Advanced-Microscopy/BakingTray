function settings=default_BT_Settings
    % Return a set of default system settings to write to a file in the settings directory
    %
    %


    % Name of the microscope to distinguish it from others
    settings.SYSTEM.ID='SYSTEM_NAME';

    % Default X/Y stage speed in mm/s
    settings.SYSTEM.xySpeed=25.0;

    % If 1 the cutter is to the right of the objective. If -1 it's to the left.
    settings.SYSTEM.cutterSide=1;

    %If true, BakingTray homes the Z jack if the user moves to zero (lowered) from a
    % large distance away. THE HOME POSITION MUST BE THE LOWERED POSITION!
    settings.SYSTEM.homeZjackOnZeroMove=1;

    % The  stage axis which will conduct the bulk of the motions in the S-shaped tile scan
    settings.SYSTEM.dominantTilingDirection='y';

    % The default path to bring up for saving data. If missing or not valid we use
    % the current directory instead.
    settings.SYSTEM.defaultSavePath='C:\';

    % autoROIchannelOrder The first available of these channels will be used for the autoROI.
    settings.SYSTEM.autoROIchannelOrder={'red','green','blue'};

    % The position of the X stage at the point at which the blade tip reaches the end of the slide
    settings.SYSTEM.bladeXposAtSlideEnd=nan;

    % The position of the X and Y stage at the point where the objective lies directly over
    % the near left corner of the slide [xPos,yPos]
    settings.SYSTEM.slideFrontLeft={nan,nan};
    settings.SYSTEM.raisedZposition=[];
    settings.SYSTEM.raisedXposition=[];


    % This is the username that appears with a Slack message
    settings.SLACK.user='@SYSTEM';

    % This is the Slack hook for sending messages
    settings.SLACK.hook=[];

    % Speed with which the blade approaches the agar block
    settings.SLICER.approachSpeed=25.0;

    % Cutter vibration rate. Can be in RPM if you have set up the encoder
    settings.SLICER.vibrateRate=10.0;

    % How long to wait after cutting for the slice to settle
    settings.SLICER.postCutDelay=6.0;

    % How fast to vibrate during the wait period (again, can be RPM)
    settings.SLICER.postCutVibrate=3.0;

    % The Y position to which to move the stage before cutting. Same for all samples
    settings.SLICER.defaultYcutPos=0;
