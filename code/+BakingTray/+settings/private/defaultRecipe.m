function dRecipe=defaultRecipe
    % Return a default recipe which is used to populate the settings file if no recipe is in there
    %

    % The default recipe has reasonable values as the 
    % defaults. 


    dRecipe.sample.ID='';
    dRecipe.sample.objectiveName='nikon 16x';

    dRecipe.mosaic.sectionStartNum=1;
    dRecipe.mosaic.numSections=1;
    dRecipe.mosaic.cuttingSpeed=0.5;
    dRecipe.mosaic.cutSize=22;
    dRecipe.mosaic.sliceThickness=0.1;
    dRecipe.mosaic.numOpticalPlanes=2;
    dRecipe.mosaic.overlapProportion=0.05;
    dRecipe.mosaic.sampleSize.X=1;
    dRecipe.mosaic.sampleSize.Y=1;
    dRecipe.mosaic.scanmode='tile';