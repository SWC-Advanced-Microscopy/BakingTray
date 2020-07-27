function H=overlayPointsOnImage(obj,x,y)
    % Plot red circles onto preview image and return handle to the plot object
    %
    % function H=acquisition_view.overlayPointsOnImage(x,y)
    %
    % Purpose
    % This method is for test and development purposes. It is used to overlay points
    % onto the current preview image. It is not called by other methods.
    % See also overlayTileGridOnImage, and overlayBoundingBoxesOnImage.m
    %
    % Inputs
    % EITHER:
    % x - scalar or vector of image x axis locations at which to plot.
    % y - scalar or vector of image y axis locations at which to plot.
    %
    % OR:
    % x - a cell array of matrices where each has two columns, the first is
    %     y axis position and the second x axis positions. This method
    %     loops through the cell array, plotting all data.
    %
    % Outputs
    % H - handle to plotted data
    %


    H=[];

    if nargin<2
        return
    end

    % Handle case where x is a cell array
    if nargin==2 && iscell(x)
        B=x;
    else
        B=[];
    end

    hold(obj.imageAxes,'on')

    if isempty(B) && nargin==3
        % The user provided two input arguments
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
