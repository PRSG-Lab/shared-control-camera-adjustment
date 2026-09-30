function report=RUN_VALIDATE(destination)
%RUN_VALIDATE Bounded analytical and archived-data validation; no full rerun.
root=prpaper_setup();
if nargin<1,destination=fullfile(root,'validation','runtime');end
if ~isfolder(destination),mkdir(destination);end
start=tic;
report=struct('passed',false,'package_version','1.1.0','matlab',version,...
 'release',version('-release'),'platform',computer,...
 'created_utc',jog2.Util.utc(),'scope','Analytical identities and archived result postprocessing; full production Monte Carlo is separate.');
report.base=jog_selftest_v2(jog_config_v2('smoke'));
report.native=prnc_selftest();prpaper_setup();
D=prpaper_collect(fullfile(root,'data','reference'));
opt=prpaper_config('paper');A=prpaper_analyze(D,opt);
T=prpaper_tables(D,A,destination,opt);
report.analysis=A.validation;
report.reduced=A.reduced.summary;
assert(report.reduced.conditions==27&&report.reduced.below_limit==13&&report.reduced.above_limit==14);
assert(report.reduced.guard_fallbacks==0);
b=A.reduced.bootstrap;z=b(strcmp(b.Suite,'J07')&strcmp(b.Component,'position'),:);
assert(abs(z.CI95_low-.03112)<.000005&&abs(z.CI95_high-.03269)<.000005);
for id={'Table1','Table2','Table3','Table4','Table5','TableS1','TableS2','TableS3','TableS4','TableS5'}
 assert(isfield(T,id{1})&&istable(T.(id{1}))&&height(T.(id{1}))>0,'Missing paper table %s',id{1});
end
assert(height(T.Experiment_crosswalk)==7);
ref=T.Table2;idx=strcmp(string(ref.Method),'GH_FULL');assert(nnz(idx)==1);
assert(abs(ref.Full_camera_coverage_pct(idx)-94.7)<1e-8,'Reference coverage changed');
report.fit_accounting=table2struct(T.Fit_accounting_totals);
assert(report.fit_accounting.Conditions==123&&report.fit_accounting.Fits==416000&&report.fit_accounting.Valid_fits==415744);
report.table_count=10;report.experiment_crosswalk_rows=7;
report.chart_paired_counts=A.chart.paired_counts;
report.chart_coverage=A.chart.coverage;
report.fixed_log_centered_scatter=A.chart.fixed_metrics.log.centered_scatter_nees;
report.fixed_direct_centered_scatter=A.chart.fixed_metrics.direct.centered_scatter_nees;
report.passed=true;report.elapsed_seconds=toc(start);
save(fullfile(destination,'validation_report.mat'),'report','-v7');
fid=fopen(fullfile(destination,'validation_report.json'),'w');clean=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));clear clean
fprintf('Validation passed (%.1f s).\n',report.elapsed_seconds);
end
