function file=RUN_FIGURES(output_file,destination,opt)
% Re-render figures and tables from the unified output.mat, without fitting.
assert(nargin>=2,'Pass a unified output.mat and NEW destination folder.');
if nargin<3,a=load(output_file,'output');opt=prpaper_config(a.output.profile);end
opt.source_file=output_file;opt.destination=destination;
file=prpaper_run('figures',opt);
end
