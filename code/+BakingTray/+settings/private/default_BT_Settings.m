function settings=default_BT_Settings
    % Return a set of default system settings to write to a file in the settings directory
    %
    % settings.SYSTEM.ID='SYSTEM_NAME';
    % settings.SYSTEM.xySpeed=100.0; %X/Y stage speed in mm/s
    % settings.SYSTEM.objectiveZSettlingDelay=0.05; %Number of seconds to wait before imaging the next optical plane
    % settings.SYSTEM.cutterSide=1; %if 1 the cutter is to the right of the objective. If -1 it's to the left.
    % settings.SYSTEM.defaultFrontLeft=[0,0]; %Use any reasonable value for the front left position. This is basically just a user courtesy issue.
    %
    % settings.SLACK.user='@SYSTEM'; % This is the username that appears with a Slack message
    % settings.SLACK.hook=[]; % This is the hook for sending messages
    %
    % settings.SLICER.approachSpeed=25.0; %Speed with which the blade approaches the agar block
    % settings.SLICER.vibrateRate=10.0;   %Cutter vibration rate
    % settings.SLICER.postCutDelay=6.0;   %How long to wait after cutting for the slice to settle
    % settings.SLICER.postCutVibrate=3.0; %How fast to vibrate during the wait period



    settings.SYSTEM.ID='SYSTEM_NAME';
    settings.SYSTEM.xySpeed=100.0;
    settings.SYSTEM.cutterSide=1;
    settings.SYSTEM.defaultFrontLeft=[0,0];

    settings.SLACK.user='@SYSTEM';
    settings.SLACK.hook=[];

    settings.SLICER.approachSpeed=25.0;
    settings.SLICER.vibrateRate=10.0;
    settings.SLICER.postCutDelay=6.0;
    settings.SLICER.postCutVibrate=3.0;

