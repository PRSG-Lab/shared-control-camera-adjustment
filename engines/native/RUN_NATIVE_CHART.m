% Full native-chart extension. Run this file after extracting the package.
root=fileparts(mfilename('fullpath')); addpath(root);
revision_root=strtrim(fileread(fullfile(root,'default_revision_root.txt')));
% If the PR folder has moved, set revision_root to its new location here.
opt=prnc_config('paper');
% If the original large output.mat has moved, set opt.original_file explicitly.
% opt.original_file='/new/path/to/original/output.mat';
destination=fullfile(root,'results','native_chart_paper');
output_file=prnc_run(revision_root,destination,opt);
