function BoundingBox = validateBoundingBox(BoundingBox,imSize)
    % Ensure bounding box remains within the image FOV (imSize)
    %
    % function BoundingBox = validateBoundingBox(BoundingBox,imSize)
    %
    % Purpose
    % Ensure we don't have bounding boxes that stray outside of the available space
    %
    % Inputs
    % BoundingBox - 1 by 4 vector defining one bounding box
    % imSize is the output of size(im) from the image where the bounding box was determined. 
    %
    % 


    verbose=false;

    BoundingBox = [floor(BoundingBox(1:2)),ceil(BoundingBox(3:4))];

    if BoundingBox(1)<1
        if verbose
            fprintf('Capping RR1 from %d to 1\n',BoundingBox(1))
        end
        BoundingBox(1)=1;
    end
    if BoundingBox(2)<1
        if verbose
            fprintf('Capping RR2 from %d to 1\n',BoundingBox(2))
        end
        BoundingBox(2)=1;
    end

    if (BoundingBox(3)+BoundingBox(1)) > imSize(2)
        if verbose
            disp('Capping RR3')
        end
        BoundingBox(3) = imSize(2)-BoundingBox(1);
    end

    if (BoundingBox(4)+BoundingBox(2)) > imSize(1)
        if verbose
            fprintf('Capping RR4 from %d to %d\n', BoundingBox(4),imSize(1)-BoundingBox(2))
        end
        BoundingBox(4) = imSize(1)-BoundingBox(2);
    end