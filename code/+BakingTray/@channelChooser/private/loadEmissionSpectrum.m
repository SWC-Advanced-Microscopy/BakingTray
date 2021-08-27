function tSpectrum = loadEmissionSpectrum(dye)
    % Load emission spectrum data from file and return
    % valid dyes are in "emission_spectra" directory
    %
    % 

    % Get the path to the emission spectra
    tPath = fileparts(which('BakingTray.channelChooser'));
    tPath = fullfile(tPath,'emission_spectra',[lower(dye),'.txt']);


    if ~exist(tPath,'file')
        fprintf('%s finds no file at %s\n', mfilename, tPath)
        tSpectrum = [];
        return
    end


    tSpectrum = dlmread(tPath);