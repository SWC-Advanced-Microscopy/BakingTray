
The folder structure reflects the fact that different algorithms for finding tissue are catered for. 
Everything in +autoROI should be common to all algorithms.
Individual algorithms should be in module directories named +dynamicThresh_Alg or +chunkDL_Alg or whatever.
autoROI.m will handle which algorithms are run. It should be transparent to the user.


Common entry functions that will divert to the correct algorithm sub-dir:
autoROI
autoROI.autothresh

autoROI.readSettings <- NOTE alg-specific functions should probably reading from their own settings file. Need to think about this