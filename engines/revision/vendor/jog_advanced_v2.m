function result=jog_advanced_v2(file,opt)
%JOG_ADVANCED_V2 Optional J16: explicit modules, no automatic expensive runs.
% Modules: hessian, reparameterization, bootstrap, profile.
o=jog2.Store.metadata(file);cfg=o.config;if nargin<2,opt=cfg.j16;end
assert(all(ismember(opt.modules,{'hessian','reparameterization','bootstrap','profile'})),'Unknown J16 module');
chosen=[];
for delta=[.15 .02]
 ix=find(cellfun(@(c)c.spec.n==30&&abs(c.spec.depth_spread-delta)<1e-12&&c.spec.noise_scale==1,o.conditions),1);
 if ~isempty(ix),chosen(end+1)=ix;end
end
if ~isfield(o,'extra_datasets'),o.extra_datasets={};end
result=struct('status','complete','modules',{opt.modules},'conditions',{{}},...
 'limitations','Conditional valid-fit diagnostics; bootstrap/LR are not finite-sample guarantees.');
for ii=1:numel(chosen)
 c=o.conditions{chosen(ii)};d=jog2.Store.design(file,c);m=find(strcmp(d.methods,'GH_FULL'),1);
 if isempty(m),continue;end
 F=d.covariance_factors{m};truth=d.geometry.truth_camera;rout=struct('source_condition',c.prefix);
 if ismember('hessian',opt.modules)
  F0=F/d.spec.noise_scale;D=size(F0,2);limit=D;
  if isfield(opt,'max_directions'),limit=min(limit,opt.max_directions);end
  bias=nan(10,numel(opt.steps));valid=true(limit,numel(opt.steps));
  directional=nan(10,limit,numel(opt.steps));settings=cfg;
  settings.solver.step_tolerance=1e-10;settings.solver.constraint_tolerance=1e-11;
  for h=1:numel(opt.steps)
   step=opt.steps(h);
   for q=1:limit
    yp=d.geometry.y_true+reshape(step*F0(:,q),5,[]);
    ym=d.geometry.y_true-reshape(step*F0(:,q),5,[]);
    rp=jog.solve_camera(yp,F,{truth},settings);rm=jog.solve_camera(ym,F,{truth},settings);
    valid(q,h)=rp.success&&rm.success;
    if valid(q,h),directional(:,q,h)=(jog.Camera.error(rp.camera,truth)+jog.Camera.error(rm.camera,truth))/step^2;end
   end
   if all(valid(:,h)),bias(:,h)=.5*sum(directional(:,:,h),2);end
  end
  rout.hessian=struct('steps',opt.steps,'directional_second_derivative',directional,...
   'b2',bias,'valid',valid,'directions_used',limit,'directions_total',D,...
   'complete_trace',limit==D,'initialization','truth-local branch, diagnostic only','Q_reference','epsilon=1');
 end
 outer={};count=0;
 for bi=1:numel(c.batches)
  b=jog2.Store.read(file,c.batches{bi});
  for k=1:numel(b.trial_id)
   if count>=opt.outer_maps,break;end;count=count+1;
   item=struct('trial_id',b.trial_id(k),'source_valid',b.valid(m,k));
   if ~b.valid(m,k),outer{end+1}=item;continue;end
   y=b.observations(:,:,k);est=jog2.Util.vecCam(b.cameras(:,m,k),truth.scale);
   if ismember('reparameterization',opt.modules)
    settings=cfg;settings.solver.focal_direct=true;
    pool=jog.Camera.initialize(y,cfg);r=jog2.solve_general(y,F,pool,settings);
    item.reparameterization=r;
    item.same_camera_distance=NaN;if ~isempty(r.camera),item.same_camera_distance=norm(jog.Camera.error(r.camera,est)./cfg.solver.parameter_scale);end
    item.cost_difference=r.cost-b.cost(m,k);
   end
   if ismember('profile',opt.modules)
    % One-dimensional gamma_z profile LR evaluated at truth, df=1.
    settings=cfg;settings.solver.free_columns=setdiff(1:10,3);
    pool=jog.Camera.initialize(y,cfg);pool{end+1}=est;
    for z=1:numel(pool),pool{z}.gamma(3)=truth.gamma(3);end
    r=jog2.solve_general(y,F,pool,settings);LR=2*(r.cost-b.cost(m,k));
    item.profile=struct('target','gamma_z','dimension',1,'constrained_fit',r,'LR',LR,...
     'covered95',r.success&&LR>=-1e-7&&LR<=jog.Core.chi2(.95,1),...
     'chi_square_is_approximate',true);
   end
   if ismember('bootstrap',opt.modules)
    C=b.covariance_native(:,:,k,m);L=chol(C,'lower');mu=b.adjusted(:,:,m,k);
    scores=nan(1,opt.inner_maps);fits=cell(1,opt.inner_maps);primitive=zeros(size(F,2),opt.inner_maps);substreams=zeros(1,opt.inner_maps);observations=zeros(size(mu,1),size(mu,2),opt.inner_maps);
    for inner=1:opt.inner_maps
     assert(count<=5000,'Split advanced runs above 5000 outer maps');
     gid=(ii-1)*50+floor((count-1)/100);coupling=mod(count-1,100);
     [rs,sid]=jog2.Util.stream(cfg,16,gid,coupling,inner,4);
     zz=randn(rs,size(F,2),1);primitive(:,inner)=zz;substreams(inner)=sid;
     yy=mu+reshape(F*zz,5,[]);observations(:,:,inner)=yy;
     pool=jog.Camera.initialize(yy,cfg);r=jog.solve_camera(yy,F,pool,cfg);r.bootstrap_substream=sid;
     fits{inner}=r;if r.success,e=jog.Camera.error(r.camera,est);scores(inner)=sum((L\e).^2);end
    end
    threshold=jog.Core.quantile(scores,.95);err=-b.errors(:,k,m);actual=sum((L\err).^2);
    item.bootstrap=struct('scores',scores,'threshold95',threshold,'fits',{fits},...
     'observations',observations,'primitive_normals',primitive,'substreams',substreams,'covered95',actual<=threshold,'valid_count',nnz(isfinite(scores)),...
     'region','bootstrap-calibrated fixed-outer-covariance Wald','outer_nees',actual);
   end
   var=sprintf('%s_J16g%02do%04d',o.meta.run_id,ii,count);payload=struct();payload.(var)=item;
   o.extra_datasets{end+1}=jog2.Archive.putValue(file,var,item,'advanced');
   outer{end+1}=struct('variable',var,'trial_id',item.trial_id,'source_valid',item.source_valid);
  end
  if count>=opt.outer_maps,break;end
 end
 rout.outer=outer;result.conditions{end+1}=rout;
end
% Optional experiments can be large: separate top-level variable, same MAT.
prefix=[o.meta.run_id '_J16'];o.extra_datasets{end+1}=jog2.Archive.putValue(file,prefix,result,'advanced');
o.diagnostics.J16=struct('variable',prefix,'modules',{opt.modules},'status','complete');
jog2.Store.saveMetadata(file,o);
end
