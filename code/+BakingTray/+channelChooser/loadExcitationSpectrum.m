function tSpectrum = loadExcitationSpectrum(dye)
    % Load excitation spectrum data from file and return
    % valid dyes are in "excitation_spectra_2p" directory
    %
    % Returned data format:
    % Col 1 - wavelength
    % Col 2 - the two photon absorption spectrum (aka 2PA cross section)
    % Col 3 - the two-photon brightness (aka action cross section)


    % Get the path to the emission spectra
    tPath = fileparts(which('BakingTray.channelChooser'));
    tPath = fullfile(tPath,'excitation_spectra_2p',[lower(dye),'.txt']);


    if ~exist(tPath,'file')
        fprintf('%s finds no file at %s\n', mfilename, tPath)
        tSpectrum = [];
        return
    end


    tSpectrum = dlmread(tPath);
