function success=attachRecipe(obj,fname,resume)
    % Attach recipe  BT
    %
    % function success=attachRecipe(obj,fname,resume)
    %
    % Purpose
    % Adds a "recipe" to the BT object. The recipe is the file which desfines
    % how the acquisition will proceed. e.g. the number of sections, the 
    % extent of arear to be imaged, etc. The recipe itself is an object that 
    % also stores the image size, etc, and calculates the number of tiles, tile
    % positions and so forth. 
    %
    %
    % Inputs
    % fname - The name of the recipe to load. If missing it loads the built-in default 
    %         recipe that is present in the SETTINGS folder.
    % resume - False by default. If true we load the full settings of the resip to
    %          to attempt to resume it. See help recipe.
    %
    %
    % Outputs
    % success - Returns true if  recipe was added. 
    %

    if nargin<2
        fname=[];
    end

    if nargin<3
        resume=false;
    end

    %If recipe was not a valid recipe name just exit and indicate failure
    if isempty(fname)
        obj.recipe=recipe(fname);
        obj.recipe.parent=obj;
        if ~isempty(obj.recipe)
            success=true;
        else
            success=false;
        end
        return
    end


    if ~isstr(fname) || exist(fname,'file')~=2
        success=false;
    else
        [~,~,ext]=fileparts(fname);
        if ~strcmpi(ext,'.yml') && ~strcmpi(ext,'.yaml')
            fprintf('Selected file is not a YAML.\n')
            success=false;
        else
            success=true; %so far...
        end
    end

    if success
        %Return false if the attachment of the recipe failed
        obj.recipe=recipe(fname,'resume', resume);

        %Set the stage speeds
        obj.setXYvelocity(obj.recipe.SYSTEM.xySpeed);

        if isempty(obj.recipe)
            fprintf('Attempted to read recipe but failed\n')
            success=false;
        else
            obj.recipe.parent=obj;
            success=true;
        end
    end

end
