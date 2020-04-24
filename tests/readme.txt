This directory contains code for unit testing BakingTray. 
You do not need to add this directory to your path. 

To run the unit tests:

>> runtests

or 

>> table(runtests)

To run specific tests:
>> run(BT_build_tests);
>> run(recipe_tests);


What if there are failures? For example, say we see:

Failure Summary:

     Name                                            Failed  Incomplete  Reason(s)
    =============================================================================================
     recipe_tests/checkTilePositions                   X                 Failed by verification.
    ---------------------------------------------------------------------------------------------
     recipe_tests/checkHandlingOfSystemSettingsLoad    X                 Failed by verification.



Run just one test:
 T=recipe_tests 
 T.checkTilePositions

