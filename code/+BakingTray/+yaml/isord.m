function result = isord(obj)
import BakingTray.yaml.*;
result = ~iscell(obj) && any(size(obj) > 1);
end
