function [out,pathToYML]=readBakingTrayPrefs(prefsFname)
% Read BakingTray system preferences file
%
% function [out,pathToYML]=readBakingTrayPrefs(prefsFname)
%
% Purpose:
% The YML file called 'baking_prefs.yml' stores the system-specific parameters.
% These are not experiment specific and won't need changing between experiments.
%
% Inputs
% prefsFname   - [optional] if empty or missing the string 'baking_prefs.yml' is used. 
%
% Outputs
% out - the contents of the YML file as a structure.
% pathToYML - Path to the INI file
%
%
% Rob Campbell - Basel 2016


if nargin<1 || isempty(prefsFname)
    prefsFname='baking_prefs.yml';
end

if nargin<2
    processIni=1;
end


if ~exist(prefsFname,'file')
    error('%s - can not find file %s.\n', mfilename, prefsFname);
end


%Read INI file
out = yaml.ReadYaml(prefsFname);
pathToYML = which(prefsFname); %So we optionally return the path to the preferences file

%Load the default INI file
default = yaml.ReadYaml('baking_prefs_DEFAULT.yml');


%Check that the user INI file contains all the keys that are in the default
fO=fields(out);
fD=fields(default);

for ii=1:length(fD)

    if isempty(strmatch(fD{ii},fO,'exact'))
        fprintf('Missing section %s in YML file %s. Using default values\n', fD{ii}, which(prefsFname))
        out.(fD{ii}) = default.(fD{ii}) ;
        continue
    end



    %Warning: descends down only one layer
    sO = fields(out.(fD{ii}));
    sD = fields(default.(fD{ii}));
    for jj=1:length(sD)
        if isempty(strmatch(sD{jj},sO,'exact'))
           fprintf('Missing field %s in YML file %s. Using default value.\n',sD{jj}, which(prefsFname))
           out.(fD{ii}).(sD{jj}) = default.(fD{ii}).(sD{jj});
        end
    end

end
