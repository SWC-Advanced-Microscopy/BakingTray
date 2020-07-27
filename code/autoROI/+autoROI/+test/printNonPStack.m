function printNonPStack
% Identifies which saved MAT files are still arrays and need to processed to pStack structures
%
% Purpose
% Call from directory containing sub-dirs with saved pStack files.
% Reports which MAT files don't contain a structure call pStack and so 
% need to have ground truth data calculated and stored in a sturcture
%
% Outputs
% None - prints data to screen



d = dir('./**/*previewStack*.mat');

n=0;
for ii=1:length(d)
    fname=fullfile(d(ii).folder,d(ii).name);
    tmp = whos('-file',fname);

    if ~isempty(findstr(d(ii).folder,'tests'))
        % Skip: these are data associated with algorithm testing and not a pStack 
        continue
    end

    if length(tmp)>1
        fprintf('%s contains more than one variable. skipping\n', fname)
        continue
    end

    if ~strcmp(tmp.name,'pStack')
        fprintf('%s does not contain a variable called "pStack". skipping\n', fname)
        continue
    end



    if ~strcmp(tmp.class,'struct')
        fprintf('UNPROCESSED - %s\n', fname)
        n=n+1;
        continue
    end

    fprintf('DONE - %s\n', fname)

end

%Report how many samples were not processed
if n==0
    fprintf('There are no unprocessed samples\n')
elseif n==1
    fprintf('There is 1 unprocessed sample\n')
else
    fprintf('\nThere are %d unprocessed samples\n', n)
end