# BakingTray Tests

This directory contains code for unit testing BakingTray.
You do not need to add this directory to your path.

## Running tests
To run the unit tests:

>> runtests

or

>> table(runtests)

To run specific tests:
>> run(BT_build_tests);
>> run(recipe_tests);


## If there are failures?
What if there are failures? For example, say we see:

Failure Summary:

     Name                                            Failed  Incomplete  Reason(s)
    =============================================================================================
     recipe_tests/checkTilePositions                   X                 Failed by verification.
    ---------------------------------------------------------------------------------------------
     recipe_tests/checkHandlingOfSystemSettingsLoad    X                 Failed by verification.



Run just one test:

runtests('recipe_tests','ProcedureName','checkTilePositions')

or

T = recipe_tests;
run(T, 'checkTilePositions')

**NOTE**: You must run the tests using the above wrappers or the set up and tear down methods will not run.

