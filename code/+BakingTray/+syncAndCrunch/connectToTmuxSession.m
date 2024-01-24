function connectToTmuxSession(sessionName)
% Return tmux session names

%Start tmux session if it does not exist


%TODO
system('start cmd /k ssh  rob@joiner.mrsic-flogel.swc.ucl.ac.uk -t tmux attach -t empty')


% Now check that MATLAB is started in it.
