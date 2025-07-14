function abortOnFrame(src,evt)
    persistent hSI

    frameToAbort = 300;

    if ~most.idioms.isValidObj(hSI)
        hSI = dabs.resources.ResourceStore.filterByNameStatic('ScanImage');
    end

    if hSI.hStackManager.framesDone >= frameToAbort
        hSI.hScan2D.hAcq.errorOutAcquisition();
    end
end
