function isIdleBASH = tmuxBufferHasIdleBASH(txt)

    txt = BakingTray.syncAndCrunch.getTmuxBufferContents;

    % We have an idle MATLAB session if the buffer ends with '$' followed by a newline.
    isIdleBASH = endsWith(txt,sprintf('$\n'));
