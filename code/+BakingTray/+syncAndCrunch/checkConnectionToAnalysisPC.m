function isConnected = checkConnectionToAnalysisPC
    % Return true if we can ping the analysis PC


    % TODO -- change PC name!
    isConnected = false;

    if ispc
        out = system('ping -n 1 joiner.mrsic-flogel.swc.ucl.ac.uk >NUL');
        isConnected = ~out;
    else
        fprintf('%s works only on Windows right now\n', mfilename)
    end

