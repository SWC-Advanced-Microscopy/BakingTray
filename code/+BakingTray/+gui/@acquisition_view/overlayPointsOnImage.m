function H=overlayPointsOnImage(obj,x,y)
    % Overlay points at defined x and y locations on preview image. This function used for testing right now. 
    % TESTING
    % TODO -- tidy and doc if we are to keep this
    
    if nargin<2 && ~iscell(x)
        x = rand(1,200) * 100;
        y = rand(1,200) * 100;
    end

    if iscell(x)
        B=x;
    else
        B=[];
    end

    hold(obj.imageAxes,'on')

    if isempty(B)
        H=plot(x,y,'or','Parent',obj.imageAxes);
    else
        for ii=1:length(B)
            x=B{ii}(:,2);
            y=B{ii}(:,1);
            H(ii)=plot(x,y,'or','Parent',obj.imageAxes);
        end
    end


    hold(obj.imageAxes,'off')
end %overlayPointsOnImage
