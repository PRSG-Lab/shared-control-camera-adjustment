% Path and mathematics check on saved data; these are NOT paper results.
root=fileparts(mfilename('fullpath')); addpath(root);
revision_root=strtrim(fileread(fullfile(root,'default_revision_root.txt')));
opt=prnc_config('smoke');
output_file=prnc_run(revision_root,fullfile(root,'results','native_chart_smoke'),opt);
