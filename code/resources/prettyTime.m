function time = prettyTime(timeInSeconds)
    % Turns a time in seconds into a nicely formated string
    %
    % function time = prettyTime(timeInSeconds)
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
    % time - a string along the lines of '2 hrs 4 mins'
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


    disp(timeInSeconds)

    [~,~,D,H,M,S] = datevec(timeInSeconds / (24*60^2) )

    time=''; %The nicely formatted time string will be incrementally built

    n=0; %number of messages added

    if D>=3
        time = sprintf('%s%d days ', time, D); 
        n=n+1;
    end

    if H > 0
        if D < 3
            H = H + D*24;
        end
        time = sprintf('%s%d hrs ', time, H); 
        n=n+1;
    end

    if M > 0 && n<2
        time = sprintf('%s%d min ', time, M);
        n=n+1;
    end

    if  S > 0 && n<2
        % Only adds seconds if hours were zero
        time = sprintf('%s%d sec', time, round(S));
        n=n+1;
    end


    if isempty(time)
        time = '0 s';
    elseif strcmp(time(end),' ')
        time(end)=[];
    end

end
