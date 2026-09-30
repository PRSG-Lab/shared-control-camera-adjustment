function root=prpaper_setup()
%PRPAPER_SETUP Use only the engines shipped in this package.
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'engines','revision','vendor'),'-begin');
addpath(fullfile(root,'engines','revision'),'-begin');
addpath(fullfile(root,'engines','native'),'-begin');
addpath(fullfile(root,'src'),'-begin');addpath(root,'-begin');
assert(startsWith(which('jog2.Store'),fullfile(root,'engines','revision','vendor')),...
 'PRPAPER:Path','Another jog2 package shadows the bundled dependency.');
end
