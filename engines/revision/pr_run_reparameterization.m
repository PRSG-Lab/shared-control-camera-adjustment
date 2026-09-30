function out=pr_run_reparameterization(source,destination,opt)
% OPTIONAL: direct-focal chart on SAME observed data and observed-DLT pool.
% Same likelihood/model. A coordinate change is not a new physical estimator.
pr_setup();if nargin<3,opt=pr_config('paper');end
[st,o]=prrev.IO.begin(source,destination,opt,'direct_focal_diagnostic');done=0;out=fullfile(destination,'checkpoint.mat');
ix=[];
for i=1:numel(o.conditions)
 c=o.conditions{i};key=sprintf('%sc%03d',c.suite,c.spec.condition_id);
 if isempty(opt.reparameterization.condition_id),take=strcmp(c.suite,'J10')&&c.spec.n==30&&abs(c.spec.depth_spread-.02)<1e-10&&abs(c.spec.noise_scale-1)<1e-10;
 else,take=strcmp(key,opt.reparameterization.condition_id)||strcmp(c.prefix,opt.reparameterization.condition_id);end
 if take,ix(end+1)=i;end
end
assert(numel(ix)==1,'Select exactly one condition');c=o.conditions{ix};d=jog2.Store.design(st.source,c);m=find(strcmp(d.methods,'GH_FULL'),1);assert(~isempty(m),'GH_FULL missing');
settings=o.config;settings.solver.focal_direct=true;rows=struct([]);count=0;
for bi=1:numel(c.batches)
 if count>=opt.reparameterization.max_maps,break;end
 b=jog2.Store.read(st.source,c.batches{bi});
 for k=1:numel(b.trial_id)
  if count>=opt.reparameterization.max_maps,break;end
  count=count+1;key=sprintf('direct_focal_trial%05d',b.trial_id(k));[yes,v]=prrev.IO.cached(st,key);
  if ~yes
   y=b.observations(:,:,k);pool=jog.Camera.initialize(y,o.config);r=jog2.solve_general(y,d.covariance_factors{m},pool,settings);
   v=struct('trial_id',b.trial_id(k),'fit',r,'original_valid',b.valid(m,k),'original_camera',b.cameras(:,m,k),'original_cost',b.cost(m,k),...
    'error_common_truth',nan(10,1),'full_nees',NaN,'same_camera_distance',NaN,'physical_focal_error',NaN,'physical_focal_variance',NaN);
   if r.success
    v.error_common_truth=jog.Camera.error(r.camera,d.geometry.truth_camera);L=chol(r.covariance,'lower');v.full_nees=sum((L\(-v.error_common_truth)).^2);
    f=r.camera.scale*exp(r.camera.phi);v.physical_focal_error=f-d.geometry.truth_camera.scale*exp(d.geometry.truth_camera.phi);v.physical_focal_variance=f^2*r.covariance(7,7);
    if b.valid(m,k),orig=jog2.Util.vecCam(b.cameras(:,m,k),r.camera.scale);v.same_camera_distance=norm(jog.Camera.error(r.camera,orig)./o.config.solver.parameter_scale);end
   end
   st=prrev.IO.put(st,key,v);done=done+1;fprintf('Direct focal %d/%d\n',count,min(c.spec.N,opt.reparameterization.max_maps));
   if prrev.IO.pause(opt,done),return;end
  else,st=prrev.IO.put(st,key,v);end
  rows=prrev.IO.append(rows,struct('trial_id',v.trial_id,'original_valid',v.original_valid,'direct_valid',v.fit.success,'scaled_camera_difference',v.same_camera_distance,...
   'cost_difference',v.fit.cost-v.original_cost,'direct_full_nees_common_chart',v.full_nees,'physical_focal_error',v.physical_focal_error,'physical_focal_variance',v.physical_focal_variance));
 end
end
results=struct('source_condition',c.prefix,'rows',rows,'note','Finite-sample Wald regions depend on chart. Full NEES reported in the original log-focal chart for like-for-like comparison; direct-focal scalar errors/variance are supplied separately. Same observed initializers; no truth starts.');
writetable(struct2table(rows),fullfile(destination,'tables','reparameterization.csv'));out=prrev.IO.finish(st,results);
end
