function switchBeams(beamApower,beamBpower,intervalInS)
% switchBeams
% 
% Switch back and forth between beams during Focus
%
% intervalInS is 1s by default


API = SIBT.get_hSI_from_base;

if isempty(API)
    return
end


if nargin <3
	intervalInS = 1;
end

while 1
	API.hBeams.powers=[beamApower,0]; 
	disp([beamApower,0])
	pause(intervalInS); 

	API.hBeams.powers=[0,beamBpower]; 
	disp([0,beamBpower])
	pause(intervalInS);
end