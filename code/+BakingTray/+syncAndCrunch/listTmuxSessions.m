function sessionNames = listTmuxSessions
% Return tmux session names

% TODO -- change PC name
[out,txt] = system('ssh rob@joiner.mrsic-flogel.swc.ucl.ac.uk tmux ls ');

if contains(txt,'error')
    sessionNames = [];
    return
end


tLines = strsplit(txt,'\n');

for ii = 1:length(tLines)
    if length(tLines{ii}) == 0
        return
    end

    tmp = strsplit(tLines{ii},':');

    sessionNames{ii} = tmp{1};

end
