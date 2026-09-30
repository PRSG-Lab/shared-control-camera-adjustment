function root=pr_setup()
% Standalone dependency snapshot; place this package ahead of older versions.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'vendor'),'-begin');addpath(root,'-begin');
assert(startsWith(which('jog2.Store'),fullfile(root,'vendor')), 'PR:Path','Another jog2 package shadows bundled dependencies. Restart MATLAB and run pr_setup.');
end
