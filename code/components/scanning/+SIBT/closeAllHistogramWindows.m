function closeAllHistogramWindows
    % Close all ScanImage histogram windows
    %
    % SIBT.closeAllHistogramWindows
    %
    % Purpose
    % Closes all ScanImage histogram windows that are open.
    %
    % Rob Campbell - SWC 2024


    hSICtl = SIBT.get_hSICtl_from_base;

    if isempty(hSICtl)
        return
    end


    auxWindowNames =  {hSICtl.hAuxGUIs.Name};

    histWindows = strmatch('Pixel Histogram', auxWindowNames);

    if ~isempty(histWindows)
        close(hSICtl.hAuxGUIs(histWindows))
    end
