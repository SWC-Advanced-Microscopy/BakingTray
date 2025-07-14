# Acquisition Auto-Resume

If ScanImage loses a frame it will stop the acquisition. This is obviously very annoying. 
We therefore will set up code that asks it to automatically resume. Starting from 
SI Basic 2023.1.1 this will be possible. 



## Set up
It is necessary to edit one function in ScanImage right now in order to test the feature. 
In future this change will be baked in. Need to:

Define `ErrorOutAcquisition` in `scanimage.components.scan2d.rggscan.Acquisition` and then call it from a user function.



```matlab
function errorOutAcquisition

    hSI.abort();
    acqType = hSI.acqState;
    evtData = most.GenericEventData(acqType);
    hSI.hUserFunctions.notify('lostFrames',evtData);
end
```


The new user function:

```matlab

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
```


So `errorOutAcquisition` is just for test purposes. 


The user function will cause an abort to happen at 300 frames. 

 
