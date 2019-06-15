function pTimeStr = prettyTime(timeInSeconds)
    % Turns a time in seconds into a nicely formated string
    %
    % function pTimeStr = prettyTime(timeInSeconds)
    %
    %
    % Purpose
    % Nicely display times in seconds for things like GUI displays and progress
    % indicators. If the time is an hour or more, then seconds are left off. 
    % Displays hours, minutes, and seconds only. Not days. 
    %
    %
    % Inputs
    % timeInSeconds - a scalar representing time in seconds
    %
    % Outputs
    % pTimeStr - a string along the lines of '2 hrs 4 mins'
    %
    % 
    % Example
    % >> prettyTime(11128)
    %
    % ans =
    % 3 hrs 5 min
    %
    %
    % Alternatives
    % You could just do:
    % datestr(datenum(0,0,0,0,0,timeInSeconds),'HH:MM:SS')
    %
    %
    % Rob Campbell - Basel, 2017

    
    hrs=fix(timeInSeconds/60^2); timeInSeconds=timeInSeconds-hrs*60^2;
    mins=fix(timeInSeconds/60);  timeInSeconds=timeInSeconds-mins*60;
    secs=round(timeInSeconds);

    pTimeStr=''; % Prettified time string
    if hrs>0 , pTimeStr=sprintf('%s%d hrs ' ,pTimeStr,hrs);  end
    if mins>0, pTimeStr=sprintf('%s%d mins ',pTimeStr,mins); end
    if secs>0, pTimeStr=sprintf('%s%d secs' ,pTimeStr,secs); end
end
