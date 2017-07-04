function [thisRecipe,msg] = readRecipe(recipeFname)
    % Read a recipe YAML file and return as a structure
    %
    % function thisRecipe = BakingTray.settings.readRecipe(recipeFname)
    %
    % Purpose
    % Read a recipe YAML file and return as a structure. 
    % Checks that the recipe file has the correct field names, that these
    % fields have the correct data types and that the values are reasonable.
    % If the fields or data types are wrong, an empty matrix is returned.
    % If the values are not reasonable, a default value is provided and the 
    % user is warned. 
    % 
    % Inputs
    % recipeFname - relative or absolute path to a recipe YAML
    %
    % Outputs
    % thisRecipe - a structure containing the recipe. Returns empty
    %              if the file is not present or is not a valid recipe.
    % msg - optionally return the message the describes what went wrong
    %
    % Rob Campbell - Basel, 2017



    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    % Load the recipe

    thisRecipe=[];
    msg='';

    if ~ischar(recipeFname)
        msg=sprintf('BakingTray.settings.readRecipe requires a string as an input argument\n');
        fprintf(msg)
        return
    end

    if ~exist(recipeFname,'file')
        msg=sprintf('BakingTray.settings.readRecipe tried to load a non-existent file at %s\n',recipeFname);
        fprintf(msg)
        return
    end

    try
        tRecipe = BakingTray.yaml.ReadYaml(recipeFname);
    catch
        L=lasterror;
        fprintf(L.message)
        msg=sprintf(['\n\nFailed to read YAML. Maybe there is a mistake in your file?\n',...
                    'A common error is failing to leave a space after a ":" character.\n\n']);
        fprintf(msg);
        return
    end


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    % Check for gross errors in the recipeLoad the recipe:
    % Ensure that this is a valid recipe by confirming that all fields in the default recipe
    % are present and that the data types are the same. If the recipe is judged invalid, an
    % empty matrix is returned.

    D=defaultRecipe;


    theseFields = fields(D);

    if length(fields(tRecipe))==2 && isfield(tRecipe,'SYSTEM') && isfield(tRecipe,'SLICER')
        %Then it is a systemSettings.yml and we don't load it
        msg=sprintf('This is a system settings YML. Can not read it. You should load a "recipe" instead\n');
        fprintf(msg);
        thisRecipe=[];
        return
    end

    %Ensure that an empty sample ID is treated as a string not an empty numeric array
    %The setter in the recipe class will create a sample ID from this.
    if isempty(tRecipe.sample.ID)
        tRecipe.sample.ID='';
    end

    for tF = theseFields'

        if ~isfield(tRecipe,tF{1})
            msg=sprintf('BakingTray.settings.readRecipe finds no field "%s" in %s. NOT A RECIPE FILE\n',tF{1},recipeFname);
            fprintf(msg);
            return
        end % if ~isfield
        subFields = fields(D.(tF{1}));

        for sF = subFields'
            %Check the recipe contains each field of the default recipe
            if ~isfield(tRecipe.(tF{1}), sF{1})
                msg=sprintf('BakingTray.settings.readRecipe finds no field "%s.%s" in %s. NOT A RECIPE FILE\n',tF{1},sF{1},recipeFname);
                fprintf(msg);
                return
            end %if ~isfield

            %Check the data type of the recipe matches with the default
            recipeVal = tRecipe.(tF{1}).(sF{1});
            defaultVal = D.(tF{1}).(sF{1});
            if ~isa(recipeVal, class(defaultVal))
                msg=sprintf('BakingTray.settings.readRecipe expects "%s.%s" to be a %s but it is a %s. USING DEFAULT VALUES.\n', ...
                    tF{1},sF{1}, class(defaultVal), class(recipeVal) );
                fprintf(msg);
                return
            end %if ~isa
        end %for sF

    end %for tF


    thisRecipe = tRecipe;


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    % Check that the values read in are reasonable. Coerce unreasonable values
    % They will already be the correct type. (TODO: where is that done?)

    if mod(thisRecipe.mosaic.sectionStartNum,1)>0
        msg=sprintf('%smosaic.sectionStartNum was not an integer. Setting it to %d\n', msg, D.mosaic.sectionStartNum)
        thisRecipe.mosaic.sectionStartNum = D.mosaic.sectionStartNum;
    end
    if thisRecipe.mosaic.sectionStartNum<1
        msg=sprintf('%smosaic.sectionStartNum was less than 1. Setting it to %d\n', msg, D.mosaic.sectionStartNum)
        thisRecipe.mosaic.sectionStartNum = D.mosaic.sectionStartNum;
    end


    if mod(thisRecipe.mosaic.numSections,1)>0
        msg=sprintf('%smosaic.numSections was not an integer. Setting it to %d\n', msg, D.mosaic.numSections)
        thisRecipe.mosaic.numSections = D.mosaic.numSections;
    end


    if thisRecipe.mosaic.numSections<1
        msg=sprintf('%smosaic.numSections was less than 1. Setting it to %d\n', msg, D.mosaic.numSections)
        thisRecipe.mosaic.numSections = D.mosaic.numSections;
    end


    if thisRecipe.mosaic.cuttingSpeed==0
        msg=sprintf('%smosaic.cuttingSpeed was zero. Setting it to %0.3f\n', msg, D.mosaic.cuttingSpeed)
        thisRecipe.mosaic.cuttingSpeed = D.mosaic.cuttingSpeed;
    end


    if thisRecipe.mosaic.cutSize<1
        msg=sprintf('%smosaic.cutSize was less than 1. Setting it to %0.1f\n', msg, D.mosaic.cutSize)
        thisRecipe.mosaic.cutSize = D.mosaic.cutSize;
    end


    if thisRecipe.mosaic.sliceThickness==0
        msg=sprintf('%smosaic.sliceThickness was zero. Setting it to %0.1f\n', msg, D.mosaic.sliceThickness)
        thisRecipe.mosaic.sliceThickness = D.mosaic.sliceThickness;
    end
    

    if mod(thisRecipe.mosaic.numOpticalPlanes,1)>0
        msg=sprintf('%smosaic.numOpticalPlanes was not an integer. Setting it to %d\n', msg, D.mosaic.numOpticalPlanes)
        thisRecipe.mosaic.numOpticalPlanes = D.mosaic.numOpticalPlanes;
    end
    if thisRecipe.mosaic.numOpticalPlanes<1
        msg=sprintf('%smosaic.numOpticalPlanes was less than 1. Setting it to %d\n', msg, D.mosaic.numOpticalPlanes)
        thisRecipe.mosaic.numOpticalPlanes = D.mosaic.numOpticalPlanes;
    end


    if thisRecipe.mosaic.overlapProportion<0 || thisRecipe.mosaic.overlapProportion>0.5
        msg=sprintf('%smosaic.overlapProportion should be between 0 and 0.5. Setting it to %0.1f\n', msg, D.mosaic.overlapProportion)
        thisRecipe.mosaic.overlapProportion = D.mosaic.overlapProportion;
    end


    if isempty(thisRecipe.mosaic.sampleSize.X) || isempty(thisRecipe.mosaic.sampleSize.Y) 
        msg=sprintf('%smosaic.sampleSize was empty setting to %d by %d mm\n', msg, D.mosaic.sampleSize.X,D.mosaic.sampleSize.Y)
        thisRecipe.mosaic.sampleSize.X = D.mosaic.sampleSize.X;
        thisRecipe.mosaic.sampleSize.Y = D.mosaic.sampleSize.Y;
    end

    %The following is hard-coded
    if ~strcmp(thisRecipe.mosaic.scanmode,'tile')
        msg=sprintf('%smosaic.scanmode can only take on the value "tile" at present. Correcting', msg)
        thisRecipe.mosaic.scanmode='tile';
    end

    if ~isempty(msg)
        fprintf(msg)
    end
