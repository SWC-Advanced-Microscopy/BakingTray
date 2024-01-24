function isIdleMATLAB =tmuxBufferHasIdleMATLAB(txt)

    txt = BakingTray.syncAndCrunch.getTmuxBufferContents;

    % We have an idle MATLAB session if the buffer ends with '>>' followed by a newline.
    isIdleMATLAB = endsWith(txt,sprintf('>>\n'));
