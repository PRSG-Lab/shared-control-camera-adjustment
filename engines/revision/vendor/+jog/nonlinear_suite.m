function out=nonlinear_suite(cfg,checkpoint,previous)
%NONLINEAR_SUITE J09: practical observed-data initialization and full GHM.
if nargin<2,checkpoint=[];end
out=struct('id','J09','layer','L3 full nonlinear division camera','conditions',{{}},...
 'notes','Known oracle covariance; observed DLT initialization unless explicitly tagged oracle_local.');
cases={};base=cfg.nonlinear;
for a=base.noise_scales,cases{end+1}=spec('noise_scale',base.baseline_points,base.baseline_spread,a,'patch',a);end
for a=base.depth_spreads
 if abs(a-base.baseline_spread)>1e-12,cases{end+1}=spec('depth_spread',base.baseline_points,a,1,'patch',a);end
end
for a=base.point_counts
 if a~=base.baseline_points,cases{end+1}=spec('point_count',a,base.baseline_spread,1,'patch',a);end
end
for a=base.point_counts,cases{end+1}=spec('global_translation',a,base.baseline_spread,1,'global',a);end
methods=base.methods;
if nargin>=3 && ~isempty(previous),out=previous;end
start=numel(out.conditions)+1;
for ci=start:numel(cases)
 sp=cases{ci};fprintf('  J09 condition %d/%d: %s = %g\n',ci,numel(cases),sp.sweep,sp.x);
 % Geometry uses a namespace disjoint from the per-trial noise seeds.
 gs=cfg.master_seed+200000000+sp.n*1000+round(1000*sp.depth_spread);
 g=jog.Camera.geometry(cfg,sp.n,sp.depth_spread,gs);truth=g.truth_camera;
 no=jog.Camera.noiseModel(cfg,g,sp.noise_scale,sp.kind);N=cfg.mc_nonlinear;nm=numel(methods);
 obs=zeros(5,sp.n,N);localerr=zeros(5*sp.n,N);b=zeros(size(no.Q_b,1),N);seeds=zeros(1,N);
 pools=cell(1,N);runs=cell(nm,N);esterror=nan(10,N,nm);covcommon=nan(10,10,N,nm);covnative=covcommon;
 valid=false(nm,N);factor=cell(1,nm);references=cell(1,nm);
 [~,A0,B0]=jog.Camera.evaluate(g.y_true,truth);
 for mi=1:nm
  factor{mi}=jog.Camera.factor(no,methods{mi});Sm=B0*(factor{mi}*factor{mi}')*B0';
  Lm=chol((Sm+Sm')/2,'lower');[C,~,~,~]=jog.Core.normal(Lm\A0,cfg.solver.rank_tolerance);
  W=C*(Lm\A0)'/Lm*B0;
  references{mi}=struct('nominal_covariance',C,'actual_sampling_covariance',W*no.Q_full*W',...
   'sensitivity',W,'design_is_oracle',true);
 end
 for k=1:N
  seeds(k)=jog.Core.seed(cfg,9,ci,k);rng(seeds(k),'twister');
  localerr(:,k)=no.F_local*randn(5*sp.n,1);b(:,k)=chol(no.Q_b,'lower')*randn(size(no.Q_b,1),1);
  obs(:,:,k)=g.y_true+reshape(localerr(:,k)+no.G_raw*b(:,k),5,[]);
  if strcmp(base.initialization,'observed_DLT_multistart')
   pool=jog.Camera.initialize(obs(:,:,k),cfg);
  elseif strcmp(base.initialization,'oracle_local')
   pool={truth}; % Explicit diagnostic, separately tagged in output.
  else,error('Unknown initialization mode.');end
  pools{k}=pool;
  for mi=1:nm
   r=jog.solve_camera(obs(:,:,k),factor{mi},pool,cfg);
   if ~isempty(r.camera)
    err=jog.Camera.error(r.camera,truth);esterror(:,k,mi)=err;
    r.error_truth_coordinates=err;r.nees_difference_at_estimate=-err;
   end
   valid(mi,k)=r.success;
   if r.success
    covnative(:,:,k,mi)=r.covariance;
    T=eye(10);T(4:6,4:6)=jog.Camera.leftInverse(esterror(4:6,k,mi));
    covcommon(:,:,k,mi)=T*r.covariance*T';
    r.covariance_common_error_coordinates=covcommon(:,:,k,mi);
    if strcmp(methods{mi},'GH_FULL')
     r.predicted_common=chol(no.Q_b,'lower')*r.latent_error(5*sp.n+1:end);
     [~,Ae,Be]=jog.Camera.evaluate(r.adjusted_observations,r.camera);
     Le=chol(Be*no.Q_local*Be','lower');dg=jog.Core.linear(Le\Ae,Le\(Be*no.G_raw),no.Q_b);
     r.common_diagnostics=rmfield(dg,{'H','Omega','W','W_direct','A','U'});
    end
   end
   runs{mi,k}=r;
  end
  if mod(k,max(1,floor(N/5)))==0,fprintf('    %d/%d maps done\n',k,N);end
 end
 summaries=cell(1,nm);
 for mi=1:nm
  e=esterror(:,:,mi);S=covcommon(:,:,:,mi);Sn=covnative(:,:,:,mi);
  % Scalar error components use a common truth-anchored chart for moments.
  ss=jog.Core.summarize(e,S,valid(mi,:),cfg.nominal);
  native=jog.Core.summarize(-e,Sn,valid(mi,:),cfg.nominal);
  ss.coverage_conditional=native.coverage_conditional;ss.coverage_operational=native.coverage_operational;
  ss.coverage_wilson=native.coverage_wilson;ss.nees=native.nees;
  ss.position=jog.Core.summarize(e(1:3,:),S(1:3,1:3,:),valid(mi,:),cfg.nominal);
  ss.eop=jog.Core.summarize(e(1:6,:),S(1:6,1:6,:),valid(mi,:),cfg.nominal);
  enative=jog.Core.summarize(-e(1:6,:),Sn(1:6,1:6,:),valid(mi,:),cfg.nominal);
  ss.eop.coverage_conditional=enative.coverage_conditional;
  ss.eop.coverage_operational=enative.coverage_operational;
  ss.eop.coverage_wilson=enative.coverage_wilson;ss.eop.nees=enative.nees;
  ss.rotation_rmse_deg=sqrt(mean(sum(e(4:6,valid(mi,:)).^2,1)))*180/pi;
  ss.focal_relative_rmse=sqrt(mean((exp(e(7,valid(mi,:)))-1).^2));
  ss.raw_reprojection_coordinate_rmse=cellfun(@(r)r.raw_reprojection_coordinate_rmse,runs(mi,:));
  ss.position_error_norm=sqrt(sum(e(1:3,:).^2,1));
  ss.ellipsoid_maxaxis95=nan(1,N);ss.ellipsoid_volume95=nan(1,N);
  for k=find(valid(mi,:))
   ev=eig(Sn(1:3,1:3,k));axes95=sqrt(jog.Core.chi2(.95,3)*max(0,ev));
   ss.ellipsoid_maxaxis95(k)=max(axes95);ss.ellipsoid_volume95(k)=4*pi/3*prod(axes95);
  end
  ss.median_maxaxis95=jog.Core.quantile(ss.ellipsoid_maxaxis95,.5);
  ss.mean_seconds=mean(cellfun(@(r)r.elapsed_seconds,runs(mi,:)));
  ss.status=cellfun(@(r)r.status,runs(mi,:),'UniformOutput',false);
  summaries{mi}=ss;
 end
 out.conditions{ci}=struct('spec',sp,'geometry_id',gs,'geometry',g,'noise_model',no,'methods',{methods},...
  'oracle_reference',{references},'covariance_factors',{factor},'trial_id',1:N,'map_id',1:N,'seed',seeds,...
  'observations',obs,'true_local_errors',localerr,'true_common_effects',b,...
  'initialization_mode',base.initialization,'shared_initializer_pool',{pools},'runs',{runs},...
  'errors',esterror,'covariance_common',covcommon,'covariance_at_estimate',covnative,...
  'valid',valid,'summary',{summaries});
 if ~isempty(checkpoint),checkpoint(out);end
end
end
function s=spec(sweep,n,spread,noise,kind,x)
s=struct('sweep',sweep,'n',n,'depth_spread',spread,'noise_scale',noise,'kind',kind,'x',x);
end
