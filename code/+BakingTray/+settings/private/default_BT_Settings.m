function settings=default_BT_Settings
    % Return a set of default system settings to write to a file in the settings directoru
    %
    % settings.SYSTEM.ID='SYSTEM_NAME';
    % settings.SYSTEM.xySpeed=100.0; %X/Y stage speed in mm/s
    % settings.SYSTEM.objectiveZSettlingDelay=0.05; %Number of seconds to wait before imaging the next optical plane
    % settings.SYSTEM.cutterSide=1; %if 1 the cutter is to the right of the objective. If -1 it's to the left.
    %
    % settings.SLICER.approachSpeed=25.0; %Speed with which the blade approaches the agar block
    % settings.SLICER.vibrateRate=60.0;   %Cutter vibration rate
    % settings.SLICER.postCutDelay=6.0;   %How long to wait after cutting for the slice to settle
    % settings.SLICER.postCutVibrate=3.0; %How fast to vibrate during the wait period



    settings.SYSTEM.ID='SYSTEM_NAME';
    settings.SYSTEM.xySpeed=100.0;
    settings.SYSTEM.objectiveZSettlingDelay=0.05;
    settings.SYSTEM.enableFlyBackBlanking=false;
    settings.SYSTEM.cutterSide=1;

    settings.SLICER.approachSpeed=25.0;
    settings.SLICER.vibrateRate=60.0;
    settings.SLICER.postCutDelay=6.0;
    settings.SLICER.postCutVibrate=3.0;

