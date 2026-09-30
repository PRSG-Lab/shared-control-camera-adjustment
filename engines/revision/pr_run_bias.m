function out=pr_run_bias(source,destination,opt)
% Deterministic Hessian-trace diagnostic on the truth-local branch.
% E[error(epsilon)] ~= epsilon^2*b2. NO new Monte Carlo population is fitted.
pr_setup();if nargin<3,opt=pr_config('paper');end
[st,o]=prrev.IO.begin(source,destination,opt,'second_order_bias');done=0;out=fullfile(destination,'checkpoint.mat');
results=struct('geometries',{{}},'rows',struct([]),'definition','Directional Hessian trace in common truth error coordinates. Truth-local diagnostic, not observed-data estimator performance.');
settings=o.config;settings.solver.step_tolerance=opt.bias.step_tolerance;settings.solver.constraint_tolerance=opt.bias.constraint_tolerance;
for gi=1:numel(opt.bias.geometry_ids)
 gid=opt.bias.geometry_ids(gi);
 ci=find(cellfun(@(c)strcmp(c.suite,'J10')&&c.spec.geometry_id==gid&&abs(c.spec.noise_scale-1)<1e-10,o.conditions));
 assert(numel(ci)==1,'Require exactly one J10 epsilon=1 condition per selected geometry');c=o.conditions{ci};d=jog2.Store.design(st.source,c);
 m=find(strcmp(d.methods,'GH_FULL'),1);assert(~isempty(m),'GH_FULL unavailable');truth=d.geometry.truth_camera;y0=d.geometry.y_true;
 F=d.covariance_factors{m};G=chol((d.noise_model.Q_full+d.noise_model.Q_full')/2,'lower');
 nd=size(G,2);limit=min(nd,opt.bias.max_directions);H=numel(opt.bias.steps);second=nan(10,limit,H);valid=false(limit,H);
 basekey=sprintf('bias_g%02d_base',gid);[yes,base]=prrev.IO.cached(st,basekey);
 if ~yes,base=jog.solve_camera(y0,F,{truth},settings);end
 st=prrev.IO.put(st,basekey,base);assert(base.success,'Truth-local zero-noise solve failed');e0=jog.Camera.error(base.camera,truth);
 for hi=1:H
  h=opt.bias.steps(hi);
  for q=1:limit
   key=sprintf('bias_g%02d_h%02d_q%04d',gid,hi,q);[yes,v]=prrev.IO.cached(st,key);
   if ~yes
    rp=jog.solve_camera(y0+reshape(h*G(:,q),5,[]),F,{truth},settings);
    rm=jog.solve_camera(y0-reshape(h*G(:,q),5,[]),F,{truth},settings);
    v=struct('direction',q,'step',h,'positive_fit',rp,'negative_fit',rm,'valid',rp.success&&rm.success,'second',nan(10,1));
    if v.valid,v.second=(jog.Camera.error(rp.camera,truth)+jog.Camera.error(rm.camera,truth)-2*e0)/h^2;end
    st=prrev.IO.put(st,key,v);done=done+1;
    fprintf('Bias G%d | step %g | direction %d/%d (%d total)\n',gid,h,q,limit,nd);
    if prrev.IO.pause(opt,done),return;end
   else,st=prrev.IO.put(st,key,v);end
   valid(q,hi)=v.valid;second(:,q,hi)=v.second;
  end
 end
 b2=nan(10,H);complete=limit==nd&all(valid,1);
 for hi=1:H,if complete(hi),b2(:,hi)=.5*sum(second(:,:,hi),2);end,end
 D=diag(o.config.solver.parameter_scale);delta=nan(1,H);
 for hi=2:H
  if complete(hi)&&complete(hi-1),delta(hi)=norm(D\(b2(:,hi)-b2(:,hi-1)))/max(norm(D\b2(:,hi)),eps);end
 end
 r=struct('geometry_id',gid,'source_condition',c.prefix,'steps',opt.bias.steps,'b2',b2,...
  'directional_second_derivative',second,'valid',valid,'directions_used',limit,'directions_total',nd,'complete_trace',complete,...
  'step_relative_change',delta,'stable_finest_pair',H>=2&&isfinite(delta(end))&&delta(end)<=opt.bias.relative_step_tolerance,...
  'metric',o.config.solver.parameter_scale,'zero_noise_error',e0,'observation_covariance_factor',G,'comparison',{{}});
 for ep=opt.bias.scales
  ix=find(cellfun(@(x)strcmp(x.suite,'J10')&&x.spec.geometry_id==gid&&abs(x.spec.noise_scale-ep)<1e-10,o.conditions));
  assert(numel(ix)==1,'Requested J10 noise scale missing');cc=o.conditions{ix};ss=prrev.IO.summary(o,cc);mm=find(strcmp(ss.methods,'GH_FULL'),1);a=ss.method{mm};
  dd=jog2.Store.design(st.source,cc);assert(norm(dd.geometry.y_true-y0,'fro')<1e-9,'Noise sweep did not preserve geometry');
  empirical=a.bias_decomposition.bias;se=a.bias_decomposition.bias_standard_error;pred=ep^2*b2;
  r.comparison{end+1}=struct('epsilon',ep,'empirical_bias',empirical,'standard_error',se,'predicted_bias',pred,'source_condition',cc.prefix,'n_valid',a.n_valid);
  for hi=1:H
   for p=1:10
    results.rows=prrev.IO.append(results.rows,struct('geometry',gid,'epsilon',ep,'step',opt.bias.steps(hi),'parameter',p,'empirical_bias',empirical(p),...
     'empirical_standard_error',se(p),'second_order_bias',pred(p,hi),'complete_trace',complete(hi),'stable_finest_pair',r.stable_finest_pair));
   end
  end
 end
 results.geometries{gi}=r;st=prrev.IO.put(st,sprintf('bias_g%02d_summary',gid),r);
end
prrev.Reports.bias(results,destination,opt);out=prrev.IO.finish(st,results);
end
