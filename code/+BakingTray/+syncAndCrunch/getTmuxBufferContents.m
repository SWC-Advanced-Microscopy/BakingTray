function out = getTmuxBufferContents(sessionName)
% Return tmux session names

%Start tmux session if it does not exist


[status,out] = system('ssh rob@joiner.mrsic-flogel.swc.ucl.ac.uk tmux capture-pane -t empty -pS -');


if status > 0
    disp(out)
    out = [];
end
