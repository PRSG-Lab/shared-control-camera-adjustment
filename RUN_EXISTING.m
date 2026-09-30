function file=RUN_EXISTING(source_file,destination,opt)
% Existing completed v2.1 archive; generates missing PR extensions as needed.
% opt.revision_root: existing PR package/results folder or postprocess MAT.
% opt.native_file: existing completed native-chart output.mat (optional).
% External sources remain read-only. Re-use this destination to resume.
if nargin<3,opt=prpaper_config('paper');end
assert(nargin>=2,'Pass original output.mat and a new destination folder.');
opt.source_file=source_file;opt.destination=destination;
file=prpaper_run('existing',opt);
end
