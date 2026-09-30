function out=pr_run_additional(source,destination,opt)
% ONLY selected J13-like stronger-rotation cases. Baseline geometry/noise paired.
% Additive first-order similarity loading, not an exact finite transformation.
pr_setup();if nargin<3,opt=pr_config('paper');end
assert(strcmp(opt.additional.noise_model,'additive_first_order_similarity'),'Only documented additive first-order similarity model is implemented');
[st,o]=prrev.IO.begin(source,destination,opt,'strong_rotation');out=fullfile(destination,'checkpoint.mat');done=0;
cfg=o.config;cfg.j13.rotation_deg=opt.additional.rotation_deg;cfg.j13.points=opt.additional.points;
cfg.mc_nonlinear=opt.additional.maps;cfg.nonlinear.methods=opt.additional.methods;
cfg.enabled={'J13'};cfg.analyze=false;cfg.make_figures=false;cfg.source_runs={};cfg.j16.enabled=false;
assert(cfg.mc_nonlinear>=1&&cfg.mc_nonlinear<10000,'Number of maps outside RNG tuple range');
cases=jog2.Plan.make('J13',cfg);results=struct('conditions',{{}},'rows',struct([]),'config',cfg,...
 'note','Same source RNG and nested geometry as original J13, with stronger rotation loading. Paired Gaussian primitives. Additive first-order similarity; do not claim exact finite-transformation invariance.');
for ci=1:numel(cases)
 sp=cases{ci};dk=sprintf('rotation_c%03d_design',ci);[yes,d]=prrev.IO.cached(st,dk);
 if ~yes
  d=jog2.Plan.prepare(sp,cfg);
  old=find(cellfun(@(c)strcmp(c.suite,'J13')&&c.spec.n==sp.n,o.conditions),1);
  assert(~isempty(old),'No original J13 geometry for n=%d',sp.n);od=jog2.Store.design(st.source,o.conditions{old});
  assert(isequaln(d.geometry.y_true,od.geometry.y_true),'PR:Geometry','Regenerated geometry differs from stored J13; do not compare unpaired experiments');
  d.source_geometry_condition=o.conditions{old}.prefix;
 end
 st=prrev.IO.put(st,dk,d);chunks={};bi=0;
 for first=1:opt.additional.batch_size:sp.N
  bi=bi+1;ids=first:min(first+opt.additional.batch_size-1,sp.N);key=sprintf('rotation_c%03d_b%04d',ci,bi);[yes,b]=prrev.IO.cached(st,key);
  if ~yes
   b=jog2.Batch.run(d,cfg,ids);st=prrev.IO.put(st,key,b);done=done+1;
   fprintf('Rotation %g deg | n=%d | maps %d/%d\n',sp.x,sp.n,ids(end),sp.N);
   if prrev.IO.pause(opt,done),return;end
  else,st=prrev.IO.put(st,key,b);end
  chunks{bi}=b;
 end
 s=prrev.Additional.summarize(chunks,d,cfg);st=prrev.IO.put(st,sprintf('rotation_c%03d_summary',ci),s);
 results.conditions{ci}=s;results.rows=prrev.IO.append(results.rows,s.rows);
end
prrev.Reports.additional(results,destination,opt);out=prrev.IO.finish(st,results);
end
