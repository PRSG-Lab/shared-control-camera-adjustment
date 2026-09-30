function opt=prpaper_config(profile)
%PRPAPER_CONFIG Explicit, reproducible settings; does not launch a run.
% paper: manuscript design/seeds; pilot and smoke: reduced, different seeds.
if nargin<1,profile='paper';end
root=prpaper_setup();profile=char(profile);
assert(ismember(profile,{'paper','pilot','smoke'}),'Use paper, pilot or smoke.');
opt=struct('version','1.1.0','profile',profile,'destination','',...
 'source_file','','revision_root','','native_file','',...
 'reference_dir',fullfile(root,'data','reference'),'stages',{{}},...
 'max_batches',Inf,'make_figures',true,'dpi',600,'figure_visible','off','include_workflow',false,...
 'export_pdf',true,'bootstrap_replicates',2000,...
 'analysis_seed',9003,'allow_incomplete',false);
opt.base=jog_config_v2(profile);
% Separate raw fitting and analysis into individually resumable stages.
% These two flags change execution order only, not any numerical experiment.
opt.base.analyze=false;opt.base.make_figures=false;
opt.revision=pr_config(profile);
if strcmp(profile,'smoke'),opt.native=prnc_config('smoke');opt.dpi=120;opt.bootstrap_replicates=100;
elseif strcmp(profile,'pilot'),opt.native=prnc_config('paper');opt.native.profile='pilot';opt.dpi=300;
else,opt.native=prnc_config('paper');end
opt.base.fig_dpi=opt.dpi;
opt.revision.make_figures=false;opt.native.make_figures=false;
end
