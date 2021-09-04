function tSpectrum = loadExcitationSpectrum(dye,returnFullSpectrum)
    % Load excitation spectrum data from file and return
    % valid dyes are in "excitation_spectra_2p" directory
    %
    % function tSpectrum = BakingTray.channelChooser.loadExcitationSpectrum(dye,returnFullSpectrum)
    %
    %
    % Inputs
    % dye - string that is dye name. e.g. 'egfp'
    % returnFullSpectrum - optional bool, false by default. If true the whole
    %                      wavelength range is returned. If false, it's clipped
    %                      between 760 and 1050 nm. 
    %
    %
    % Returned data format:
    % Col 1 - wavelength
    % Col 2 - the two photon absorption spectrum (aka 2PA cross section)
    % Col 3 - the two-photon brightness (aka action cross section)


    if nargin<2
        returnFullSpectrum = false;
    end

    % Get the path to the emission spectra
    tPath = fileparts(which('BakingTray.channelChooser'));
    tPath = fullfile(tPath,'excitation_spectra_2p',[lower(dye),'.txt']);


    if ~exist(tPath,'file')
        fprintf('%s finds no file at %s\n', mfilename, tPath)
        tSpectrum = [];
        return
    end


    tSpectrum = dlmread(tPath);


    % Smooth a little as some spectra are noisy
    tSpectrum(:,2) = conv(tSpectrum(:,2),[1,1,1]','same');
    tSpectrum(:,3) = conv(tSpectrum(:,3),[1,1,1]','same');


    % By default only return values within the normally used range of 
    % a TiSaph laser. 
    if returnFullSpectrum
        return 
    end

    f = find(tSpectrum(:,1)>1050 | tSpectrum(:,1)<760);
    tSpectrum(f,:) = [];
