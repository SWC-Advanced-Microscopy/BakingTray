classdef recipe_tests < matlab.unittest.TestCase
    % Unit tests for ensuring that the recipe class does not let the 
    % user apply settings that are out of range or otherwise inappropriate. 

    properties
        hR 
    end %properties


    methods(TestMethodSetup)
        function buildRecipe(obj)
            % Build the recipe with default parameters
            obj.hR = recipe;
            obj.verifyClass(obj.hR,'recipe');
            %Set up reasonable blade and front/left positions
            obj.hR.CuttingStartPoint.X=18;
        end
    end
 
    methods(TestMethodTeardown)
        function closeRecipe(obj)
            delete(obj.hR);
        end
    end





    methods (Test)

        function checkTilePositions(obj)
            %Build BT object with attached recipe
            hBT = BT('componentSettings',BakingTray.settings.dummy);
            hBT.recipe.CuttingStartPoint.X=18;

            %Ensure that tile positions which exceed the allowed motion area can not be produced
            obj.verifyNotEmpty(hBT.recipe.tilePattern)


            tilePosArray=hBT.recipe.tilePattern;
            if isempty(tilePosArray)
                return
            end
            minX=min(tilePosArray(:,1));
            maxX=max(tilePosArray(:,1));
            minY=min(tilePosArray(:,2));
            maxY=max(tilePosArray(:,1));


            %Min X
            hBT.xAxis.attachedStage.minPos=minX+0.1;
            obj.verifyEmpty(hBT.recipe.tilePattern);
            hBT.xAxis.attachedStage.minPos=minX-10; %reset
            obj.verifyNotEmpty(hBT.recipe.tilePattern);


            %Max X
            hBT.xAxis.attachedStage.maxPos=maxX-0.1;
            obj.verifyEmpty(hBT.recipe.tilePattern);
            hBT.xAxis.attachedStage.maxPos=maxX+10; %reset
            obj.verifyNotEmpty(hBT.recipe.tilePattern);


            %Min Y
            hBT.yAxis.attachedStage.minPos=minY+0.1;
            obj.verifyEmpty(hBT.recipe.tilePattern);
            hBT.yAxis.attachedStage.minPos=minY-10; %reset
            obj.verifyNotEmpty(hBT.recipe.tilePattern);


            %Max Y
            hBT.yAxis.attachedStage.maxPos=maxY-0.1;
            obj.verifyEmpty(hBT.recipe.tilePattern);
            hBT.yAxis.attachedStage.maxPos=maxY+10; %reset
            obj.verifyNotEmpty(hBT.recipe.tilePattern);
            
        end


        function sampleID_valid(obj)
            IDs={'mySample', 'my_Sample', 'my_sample_123'};
            for ii=1:length(IDs)
                fprintf('Testing sampleID: %s\n', IDs{ii})
                obj.hR.sample.ID=IDs{ii};
                obj.verifyTrue(strcmp(obj.hR.sample.ID,IDs{ii}));
            end
        end

        function sampleID_invalid(obj)
            IDs={'01_mySample', 'my sample','1mysample', ...
                '_mySample', '!mySample', 'my()Sample',...
                '','2342242', '}{)()}', 'abcd)(*) (*)@!123',...
                123, [],{},struct};

            for ii=1:length(IDs)
                if ischar(IDs{ii})
                    fprintf('Testing sampleID: %s\n', IDs{ii})
                else
                    %fprintf('Testing sampleID with class %s\n', class(IDs{ii}))
                end

                obj.hR.sample.ID=IDs{ii};
                if ischar(IDs{ii})
                    obj.verifyFalse(strcmp(obj.hR.sample.ID,IDs{ii}));
                else
                    %If the ID wasn't a string the returned name should start with "sample_"
                    obj.verifyTrue(strcmp(obj.hR.sample.ID(1:7),'sample_'));
                end
            end
        end

        function checkIntegerValid(obj)
            %Check just one of the integer fields, all use the same method
            testVal=[2,99,1000,10.1,0.5];
            for ii=1:length(testVal)            
                obj.hR.mosaic.sectionStartNum=testVal(ii);
                obj.verifyTrue(obj.hR.mosaic.sectionStartNum==ceil(testVal(ii)))
            end
        end

        function checkIntegerInValid(obj)
            %Check just one of the integer fields, all use the same method
            testVal={0,-1,-1.1,[],'hello','H',{},struct};
            for ii=1:length(testVal)            
                initialVal = obj.hR.mosaic.sectionStartNum;
                obj.hR.mosaic.sectionStartNum=testVal{ii};
                obj.verifyTrue(obj.hR.mosaic.sectionStartNum==initialVal)
            end
        end

        function checkOverlapPropValid(obj)
            testVal=[0,0.5];
            for ii=1:length(testVal)            
                obj.hR.mosaic.overlapProportion=testVal(ii);
                obj.verifyTrue(obj.hR.mosaic.overlapProportion==testVal(ii))
            end
        end

        function checkOverlapPropInValid(obj)
            testVal={[],'hello','H',{},struct};
            for ii=1:length(testVal)            
                initialVal = obj.hR.mosaic.overlapProportion;
                obj.hR.mosaic.overlapProportion=testVal{ii};
                obj.verifyTrue(obj.hR.mosaic.overlapProportion==initialVal)
            end
            obj.hR.mosaic.overlapProportion=-0.1;
            obj.verifyNotEqual(obj.hR.mosaic.overlapProportion,-0.1)
            obj.hR.mosaic.overlapProportion=0.7;
            obj.verifyNotEqual(obj.hR.mosaic.overlapProportion,0.7)
        end

        function checkHandlingOfSystemSettingsLoad(obj)
            %Should fail gracefully if the user tries to load the system settings file instead of a recipe
            fname=fullfile('recipes','systemSettings.yml');
            obj.verifyEmpty(BakingTray.settings.readRecipe(fname))

            fname=fullfile('recipes','recipe_experiment_170408.yml');
            obj.verifyNotEmpty(BakingTray.settings.readRecipe(fname))
        end

    end %methods (Test)


end %classdef core_tests < matlab.unittest.TestCase