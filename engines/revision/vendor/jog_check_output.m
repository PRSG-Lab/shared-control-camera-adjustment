function report=jog_check_output(filename)
%JOG_CHECK_OUTPUT Validate saved data and print a concise summary.
x=load(filename,'output');o=x.output;assert(strcmp(o.schema_version,'jog-output-1.0'));
assert(o.selftest.passed);ids=o.progress.completed_ids;
for i=1:numel(o.config.enabled),assert(ismember(o.config.enabled{i},ids),'Incomplete experiment.');end
report=struct('profile',o.config.profile,'status',o.meta.status,'experiments',{ids},...
 'figure_count',numel(o.figure_manifest),'nonlinear_counts',[]);
if isfield(o.experiments,'J09')
 cs=o.experiments.J09.conditions;rows={};
 for c=1:numel(cs)
  r=cs{c};assert(size(r.observations,3)==o.config.mc_nonlinear);
  assert(size(r.runs,2)==o.config.mc_nonlinear);
  for m=1:numel(r.methods)
   s=r.summary{m};assert(s.n_total==o.config.mc_nonlinear);
   assert(s.position.n_total==o.config.mc_nonlinear);
   rows(end+1,:)={c,r.spec.sweep,r.spec.x,r.methods{m},s.n_valid,s.n_total,s.failure_rate}; %#ok<AGROW>
  end
 end
 report.nonlinear_counts=cell2table(rows,'VariableNames',{'condition','sweep','x','method','valid','total','failure_rate'});
 disp(report.nonlinear_counts);
end
fprintf('Profile=%s, status=%s, experiments=%d, PNG figures=%d\n',report.profile,report.status,numel(ids),report.figure_count);
end
