function report=jog_verify_v2(destination)
%JOG_VERIFY_V2 Reproducible integration tests; small MC only, not paper claims.
if nargin<1,destination=fullfile(tempdir,['jog_v2_verify_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);end
if ~exist(destination,'dir'),mkdir(destination);end
cfg=jog_config_v2('smoke');cfg.j11.extensions={'M2','M3','M5'};
file=run_jog_v2(cfg,fullfile(destination,'full_smoke'));
jog_make_figures_v2(file,'legacy');
report.full_integrity=jog_check_output_v2(file);
o=jog2.Store.metadata(file);ids={o.figure_manifest.asset_id};
required=arrayfun(@(n)sprintf('F%02d',n),1:15,'UniformOutput',false);
assert(all(ismember(required,ids)),'Missing required paper assets');
assert(numel(o.legacy_figure_manifest)==16,'Missing legacy diagnostic figures');
report.figure_ids=ids;report.legacy_png_count=16;
% Resume must be equal to fresh execution for numeric scientific arrays.
small=jog_config_v2('smoke');small.enabled={'J10'};small.j10.regimes=[30 .15];
small.j10.scales=[.1 1];small.batch_size=1;small.make_figures=false;small.analyze=false;
paused=fullfile(destination,'resume');fresh=fullfile(destination,'fresh');
run_jog_v2(small,paused,'MaxBatches',1);
continued=run_jog_v2('resume',paused);complete=run_jog_v2(small,fresh);
a=jog2.Store.metadata(continued);b=jog2.Store.metadata(complete);
for c=1:numel(a.conditions)
 for k=1:numel(a.conditions{c}.batches)
  aa=jog2.Store.read(continued,a.conditions{c}.batches{k});bb=jog2.Store.read(complete,b.conditions{c}.batches{k});
  for name={'observations','eta','errors','covariance_native','candidate_camera','cost','valid'}
   assert(isequaln(aa.(name{1}),bb.(name{1})),'Resume/fresh mismatch in %s',name{1});
  end
 end
end
report.resume_equals_fresh=true;
% Single MAT copied to a clean folder must be enough to regenerate.
portable=fullfile(destination,'portable');mkdir(portable);copyfile(file,fullfile(portable,'output.mat'));
report.portable_integrity=jog_check_output_v2(fullfile(portable,'output.mat'));
report.self_contained=true;
% Optional advanced algorithms, deliberately tiny budget.
opt=cfg.j16;opt.modules={'hessian','reparameterization','bootstrap','profile'};
opt.outer_maps=1;opt.inner_maps=3;opt.max_directions=2;opt.steps=[.02 .01];
advanced=jog_advanced_v2(completeAdvancedSource(file,destination),opt);
report.advanced_smoke_modules=advanced.modules;
report.advanced_smoke_only=true;
report.completed_utc=jog2.Util.utc();report.status='passed';report.matlab_version=version;
out=fullfile(destination,'verification.json');f=fopen(out,'w');cl=onCleanup(@()fclose(f));
fprintf(f,'%s',jsonencode(report,PrettyPrint=true));disp(report);
end
function file=completeAdvancedSource(src,dest)
file=fullfile(dest,'advanced.mat');copyfile(src,file);
end
