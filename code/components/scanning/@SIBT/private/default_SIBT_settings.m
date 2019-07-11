function settings=default_SIBT_Settings
    % Return a set of default settings for the SIBT class to write to a file in the main settings directory
    %
    %
    %  The following are applied to each tile before it is plotted to screen in the preview
	%   settings.tileAcq.tileRotate=-1;
    %	settings.tileAcq.tileFlipUD=false;
	%	settings.tileAcq.tileFlipLR=false;
	%
	% 
	%  The following setting should be set to true if you have PMTs with a trip
	%  circuit that tends to be activated by bright features in your sample
	%	settings.hardware.doResetTrippedPMT = false;


    settings.tileAcq.tileRotate=-1;
    settings.tileAcq.tileFlipUD = false;
	settings.tileAcq.tileFlipLR = false;


	settings.hardware.doResetTrippedPMT = false;
