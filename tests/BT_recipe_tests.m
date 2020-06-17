classdef BT_recipe_tests < matlab.unittest.TestCase
    % Ensure changing the recipe settings work as expected with the GUI
    % This not only tests the listeners but also that the API is working
    % Some of the tests here are similar to those in recipe_tests.m, but they
    % operate on the attached recipe.

    properties
        hBT=[];
        hBTview=[];
        testRecipeFname='recipes/recipe_experiment_170408.yml'
        testRecipe
    end %properties


    methods(TestMethodSetup)
        function buildBT(obj)
            BakingTray('dummymode',true);
            W = evalin('base','whos');
            if ~ismember('hBT',{W.name}) || ~ismember('hBTview',{W.name})
                error('BT failed to build. Can not find hBT or hBTview')
            end

            % pull the objects into here
            obj.hBT = evalin('base','hBT');
            obj.hBTview = evalin('base','hBTview');

            % Load the test recipe to cross-check with attached recipe
            obj.testRecipe=BakingTray.settings.readRecipe(obj.testRecipeFname);
        end
    end

    methods(TestMethodTeardown)
        function closeBT(obj)
            delete(obj.hBTview);
        end
    end





    methods (Test)

        % - - - - - - - - 
        % Confirm we can write to the recipe and our changes are made
        function simple_write_API(obj)

            % Check strings
            IDs={'mySample', 'my_Sample', 'my_sample_123'};
            for ii=1:length(IDs)
                fprintf('Testing sampleID: %s\n', IDs{ii})
                obj.hBT.recipe.sample.ID=IDs{ii};
                obj.verifyTrue(strcmp(obj.hBT.recipe.sample.ID,IDs{ii}));
            end

            % Check numbers
            nSec = [5,10,100];
            for ii=1:length(nSec)
                fprintf('Testing write of %d sections\n', nSec(ii))
                obj.hBT.recipe.mosaic.numSections=nSec(ii);
                obj.verifyTrue(obj.hBT.recipe.mosaic.numSections==nSec(ii));
            end
        end

        % - - - - - - - - 
        % The following confirms that the changes made in the recipe are reflected 
        % in the GUI so the user will see them
        function simple_write_API_check_in_GUI(obj)
            % Check strings
            IDs={'mySample', 'my_Sample', 'my_sample_123'};
            for ii=1:length(IDs)
                fprintf('Writing sample name "%s" to sampleID\n', IDs{ii})
                obj.hBT.recipe.sample.ID=IDs{ii};
                ID_in_GUI = obj.hBTview.recipeEntryBoxes.sample.ID.String;
                fprintf('GUI contains name "%s"\n', ID_in_GUI)
                obj.verifyTrue(strcmp(ID_in_GUI,IDs{ii}));
            end

            % Check numbers
            nSec = [5,10,100];
            for ii=1:length(nSec)
                fprintf('Testing write of %d sections\n', nSec(ii))
                obj.hBT.recipe.mosaic.numSections=nSec(ii);
                numSec_in_GUI = str2double(obj.hBTview.recipeEntryBoxes.mosaic.numSections.String);
                fprintf('GUI contains %d sections\n', numSec_in_GUI)
                obj.verifyTrue(numSec_in_GUI == nSec(ii));
            end
        end

        % - - - - - - - - 
        % The following two tests confirm that recipe attachment works as expected, both in the 
        % API and also in the GUI
        function testAttach_API(obj)
            obj.hBT.attachRecipe(obj.testRecipeFname);
            % Test a string
            obj.verifyTrue(strcmp(obj.hBT.recipe.sample.ID,obj.testRecipe.sample.ID))
            % Test a number
            obj.verifyTrue(obj.hBT.recipe.mosaic.sampleSize.X==obj.testRecipe.mosaic.sampleSize.X)
        end

        function testAttach_API_check_in_GUI(obj)
            obj.hBT.attachRecipe(obj.testRecipeFname);
            GUIvals = obj.hBTview.recipeEntryBoxes;
            % Test a string
            fprintf('GUI: %s; recipe: %s\n', GUIvals.sample.ID.String, obj.testRecipe.sample.ID)
            obj.verifyTrue(strcmp(GUIvals.sample.ID.String,obj.testRecipe.sample.ID))

            % Test a number
            fprintf('GUI: %0.4f; recipe: %0.4f\n', str2double(GUIvals.mosaic.sampleSizeX.String), obj.testRecipe.mosaic.sampleSize.X)
            obj.verifyTrue(str2double(GUIvals.mosaic.sampleSizeX.String)==obj.testRecipe.mosaic.sampleSize.X)
        end

    end %methods (Test)


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    methods
        % Here can go convenience methods for running the tests

    end



end %classdef core_tests < matlab.unittest.TestCase
