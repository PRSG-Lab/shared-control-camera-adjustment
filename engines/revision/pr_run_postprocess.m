function out=pr_run_postprocess(source,destination,opt)
% Existing fits only. Never calls a camera estimator or writes the source MAT.
pr_setup();if nargin<3,opt=pr_config('paper');end
[st,o]=prrev.IO.begin(source,destination,opt,'postprocess');out=fullfile(destination,'checkpoint.mat');done=0;
ti=prrev.Diagnostics.select(o,opt,'target');di=prrev.Diagnostics.select(o,opt,'diagnostic');
results=struct('target_conditions',{{}},'diagnostics',{{}});
for ii=1:numel(ti)
 c=o.conditions{ti(ii)};d=jog2.Store.design(st.source,c);ts=prrev.Targets.design(d.geometry,o.config,opt.target);
 key=sprintf('target_summary_%03d',ti(ii));[yes,s]=prrev.IO.cached(st,key);
 if ~yes
  nb=min(numel(c.batches),opt.max_source_batches);records=cell(1,nb);
  for j=1:nb
   bk=sprintf('target_%03d_batch_%04d',ti(ii),j);[cached,v]=prrev.IO.cached(st,bk);
   if ~cached
    b=jog2.Store.read(st.source,c.batches{j});v=prrev.Targets.batch(b,d,ts,opt);st=prrev.IO.put(st,bk,v);done=done+1;
    fprintf('Targets %d/%d | batch %d/%d | %s\n',ii,numel(ti),j,nb,c.prefix);
    if prrev.IO.pause(opt,done),return;end
   else,st=prrev.IO.put(st,bk,v);end
   records{j}=v;
  end
  s=prrev.Targets.summarize(records,c.prefix);s.spec=c.spec;s.complete_source=numel(s.trial_ids)==c.spec.N;
  % Step-size sensitivity at the truth, not a validation of nonlinear coverage.
  s.jacobian_check=cell(size(ts));
  for q=1:numel(ts)
   [~,J1]=jog2.Target.values(d.geometry.truth_camera,ts{q},'plane',opt.target.derivative_step_multiplier);
   [~,J2]=jog2.Target.values(d.geometry.truth_camera,ts{q},'plane',2*opt.target.derivative_step_multiplier);
   mask=isfinite(J1)&isfinite(J2);s.jacobian_check{q}=norm(J1(mask)-J2(mask))/max(norm(J1(mask)),eps);
  end
  st=prrev.IO.put(st,key,s);
 end
 st=prrev.IO.put(st,key,s);results.target_conditions{ii}=s;
end
for ii=1:numel(di)
 c=o.conditions{di(ii)};key=sprintf('diagnostic_%03d',di(ii));[yes,r]=prrev.IO.cached(st,key);
 if ~yes
  d=jog2.Store.design(st.source,c);r=prrev.Diagnostics.condition(o,c,d,opt,di(ii));st=prrev.IO.put(st,key,r);done=done+1;
  fprintf('Diagnostics %d/%d | %s\n',ii,numel(di),c.prefix);if prrev.IO.pause(opt,done),return;end
 end
 st=prrev.IO.put(st,key,r);results.diagnostics{ii}=r;
end
prrev.Reports.post(results,destination,opt);out=prrev.IO.finish(st,results);
end
