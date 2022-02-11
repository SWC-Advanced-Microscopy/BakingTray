function settings=default_BT_Settings
    % Return a set of default system settings to write to a file in the settings directory
    %
    % settings.SYSTEM.ID='SYSTEM_NAME';
    % settings.SYSTEM.xySpeed=100.0; %X/Y stage speed in mm/s
    % settings.SYSTEM.objectiveZSettlingDelay=0.05; %Number of seconds to wait before imaging the next optical plane
    % settings.SYSTEM.cutterSide=1; %if 1 the cutter is to the right of the objective. If -1 it's to the left.
    % settings.SYSTEM.homeZjackOnZeroMove=1; %If true, BakingTray homes the Z jack if the user moves to zero (lowered) from a large distance away. THE HOME POSITION MUST BE THE LOWERED POSITION!
    % settings.SYSTEM.dominantTilingDirection='y'; % The  stage axis which will conduct the bulk of the motions in the S-shaped tile scan
    % settings.SYSTEM.defaultSavePath='C:\'; % The default path to bring up for saving data. If missing or not valid we use the current directory instead. 
    % settings.SYSTEM.autoROIchannelOrder={'red','green','blue'}; % The first available of these channels will be used for the autoROI. 
    % settings.SYSTEM.bladeXposAtSlideEnd=nan; % The position of the X stage at the point at which the blade tip reaches the end of the slide
    % settings.SYSTEM.slideFrontLeft=[nan,nan] % The position of the X andY stage at the point where the objective lies directly over the near left corner of the slide [xPos,yPos]
    % settings.SLACK.user='@SYSTEM'; % This is the username that appears with a Slack message
    % settings.SLACK.hook=[]; % This is the hook for sending messages
    %
    % settings.SLICER.approachSpeed=25.0; %Speed with which the blade approaches the agar block
    % settings.SLICER.vibrateRate=10.0;   %Cutter vibration rate
    % settings.SLICER.postCutDelay=6.0;   %How long to wait after cutting for the slice to settle
    % settings.SLICER.postCutVibrate=3.0; %How fast to vibrate during the wait period
    % settings.SYSTEM.defaultYcutPos=0; % The Y position to which to move the stage before cutting. Same for all samples


    settings.SYSTEM.ID='SYSTEM_NAME';
    settings.SYSTEM.xySpeed=25.0;
    settings.SYSTEM.cutterSide=1;
    settings.SYSTEM.homeZjackOnZeroMove=1;
    settings.SYSTEM.dominantTilingDirection='y';
    settings.SYSTEM.defaultSavePath='C:\';
    settings.SYSTEM.autoROIchannelOrder={'red','green','blue'};
    settings.SYSTEM.bladeXposAtSlideEnd=nan;
    settings.SYSTEM.slideFrontLeft={nan,nan};

    settings.SLACK.user='@SYSTEM';
    settings.SLACK.hook=[];

    settings.SLICER.approachSpeed=25.0;
    settings.SLICER.vibrateRate=10.0;
    settings.SLICER.postCutDelay=6.0;
    settings.SLICER.postCutVibrate=3.0;
    settings.SLICER.defaultYcutPos=0;
