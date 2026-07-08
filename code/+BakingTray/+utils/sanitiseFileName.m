function out_str = sanitiseFileName(in_str)
% Remove problem characters from file or directory names
%
% t_out = bakingtray.utils.sanitiseFileName(in_str)
%
% Purpose
% Keep only letters, numbers, dashes and underscores in a string
%
% Inputs
% in_str - string to sanitize.
%
% Outputs
% out_str - sanitized string
%
%
% Rob Campbell - SWC 2026


% Replace spaces with "_"
in_str = regexprep(in_str,' ','_');

% Keep only valid characters
out_str = regexprep(in_str,'[^a-z^A-Z^0-9^_^-]','');
