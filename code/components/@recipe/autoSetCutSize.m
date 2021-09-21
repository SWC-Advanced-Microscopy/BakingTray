function autoSetCutSize(obj)
	% recipe.autoSetCutSize
	%
	% If the user has set the SYSTEM.bladeXposAtSlideEnd setting in the 
	% systemSettings.yml then this method is able to use this to
	% set the cut size to a reasonable value. 


	if isnan(obj.SYSTEM.bladeXposAtSlideEnd)
		% The setting has not been defined so we can not proceed
		return
	end

	if isnan(obj.CuttingStartPoint.X)
		% The cutting start point in X is a NaN. The user
		% has not set it so we can not proceed.
		return
	end


	% If the end of the agar block is up against the end of the slide, 
	% then we know the width (cut size) exactly. If it's not we will end 
	% up cutting a little more, but that's OK. Better than too little. 
	% The user can always edit his value if needed.

	agarWidth = abs(obj.SYSTEM.bladeXposAtSlideEnd - obj.CuttingStartPoint.X);
	agarWidth = agarWidth + 2; % Add a bit in case the agar is right up against the slide end. 


	obj.mosaic.cutSize = agarWidth;


end % autoSetCutSize
