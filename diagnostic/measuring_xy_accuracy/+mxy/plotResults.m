function plotResults(IN)

    % Plot
    clf


	% Based on the step size we can figure out microns per pixel
    rangeInMicrons = range(cumsum(IN.seq)) * 1E3;
	c = IN.centroid;
	c = c - min(c);
	pixelsPerMicron = range(c) / rangeInMicrons;

	y = IN.centroid;
	y = y-mean(y(1:50)); %Subtract offset
	y = y / pixelsPerMicron;

	% x scale in seconds based on mean FPS of sequence
    x = 1:length(y);
    x = x/IN.fps;



    plot(x,y,'-b.')
    grid on


    xlabel('Time - seconds')
    ylim([min(y)-range(y)*0.01,max(y)+range(y)*0.01])
   	ylabel('Distance - microns')

