function BT_SI_userFunction(src,event,varargin)


    switch event.EventName


        case 'acqModeStart'
            fprintf(' -> Entering acquisition mode\n')


        case 'acqModeDone'
            fprintf(' -> Leaving acquisition mode\n')


        case 'acqDone'
            hSI = src.hSI; % get the handle to the ScanImage model

            if src.hSI.active
                src.hSI.hScan2D.trigIssueSoftwareAcq; %Acquire all depths and channels at this X/Y position
            end
    end % switch

end