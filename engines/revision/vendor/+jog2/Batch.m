classdef Batch
methods(Static)
function b=run(d,cfg,ids)
 n=d.spec.n;N=numel(ids);nm=numel(d.methods);no=d.noise_model;
 b=struct('trial_id',ids,'observations',zeros(5,n,N),'local_errors',zeros(5*n,N),...
 'common_effects',zeros(size(no.Q_b,1),N),'eta',zeros(5*n,N),...
 'z_local',zeros(size(no.F_local,2),N),'z_common',zeros(size(no.L_b,2),N),...
 'rng_id',zeros(2,N),'errors',nan(10,N,nm),'covariance_common',nan(10,10,N,nm),...
 'covariance_native',nan(10,10,N,nm),'valid',false(nm,N),...
 'linear_error',nan(10,N,nm),'cameras',nan(16,nm,N),'cost',nan(nm,N),...
 'iterations',zeros(nm,N),'closure',nan(nm,N),'stationarity',nan(nm,N),...
 'physical',false(nm,N),'active_bound',false(nm,N),'rank',nan(nm,N),...
 'condition_scaled',nan(nm,N),'elapsed',nan(nm,N),'selected_candidate',zeros(nm,N),...
 'reprojection',nan(2,n,nm,N),'adjusted',nan(5,n,nm,N),'correction',nan(5,n,nm,N),...
 'sensitivity',nan(10,5*n,nm,N),'latent_values',zeros(0,1),'latent_offset',zeros(2,nm,N),...
 'history_values',zeros(0,7),'history_offset',zeros(2,nm,N),...
 'candidate_camera',zeros(16,0),'candidate_info',zeros(9,0),...
 'candidate_history',zeros(0,7),'candidate_history_offset',zeros(2,0),...
 'initializer_camera',zeros(16,0),'initializer_trial',zeros(1,0),...
 'status_code',zeros(nm,N),'candidate_status_code',zeros(1,0),...
 'meta',struct('status_dictionary',{{}},'error_messages',{{}},'candidate_physical_available',true));
 for kk=1:N
  k=ids(kk);j=str2double(d.spec.suite(2:end));
  if j==9
   seed=jog.Core.seed(cfg,9,d.spec.condition_id,k);rng(seed,'twister');
   zl=randn(size(no.F_local,2),1);zb=randn(size(no.L_b,2),1);b.rng_id(:,kk)=[seed;seed];
  else
   [r,sid]=jog2.Util.stream(cfg,j,d.spec.geometry_id,d.spec.rng_coupling_id,k,1);
   % Draw max-point local arrays for nested J12/J13 comparisons.
   if any(j==[12 13]),zmax=randn(r,5,60);zl=reshape(zmax(:,1:n),[],1);else,zl=randn(r,size(no.F_local,2),1);end
   [rb,sb]=jog2.Util.stream(cfg,j,d.spec.geometry_id,d.spec.rng_coupling_id,k,2);
   zb=randn(rb,size(no.L_b,2),1);b.rng_id(:,kk)=[sid;sb];
  end
  b.z_local(:,kk)=zl;b.z_common(:,kk)=zb;b.local_errors(:,kk)=no.F_local*zl;
  b.common_effects(:,kk)=no.L_b*zb;b.eta(:,kk)=b.local_errors(:,kk)+no.G_raw*b.common_effects(:,kk);
  y=d.geometry.y_true+reshape(b.eta(:,kk),5,n);b.observations(:,:,kk)=y;
  if strcmp(cfg.nonlinear.initialization,'oracle_local'),pool={d.geometry.truth_camera};
  else,pool=jog.Camera.initialize(y,cfg);end
  for p=1:numel(pool),b.initializer_camera(:,end+1)=jog2.Util.camvec(pool{p});b.initializer_trial(end+1)=k;end
  for m=1:nm
   r=jog.solve_camera(y,d.covariance_factors{m},pool,cfg);
   b=jog2.Batch.addFit(b,r,m,kk,d.geometry.truth_camera);
   b.linear_error(:,kk,m)=d.oracle_reference{m}.sensitivity*b.eta(:,kk);
  end
 end
end
function b=addFit(b,r,m,k,truth)
 b.valid(m,k)=r.success;b.cameras(:,m,k)=jog2.Util.camvec(r.camera);
 if ~isempty(r.camera),b.errors(:,k,m)=jog.Camera.error(r.camera,truth);end
 if r.success
  b.covariance_native(:,:,k,m)=r.covariance;T=eye(10);T(4:6,4:6)=jog.Camera.leftInverse(b.errors(4:6,k,m));
  b.covariance_common(:,:,k,m)=T*r.covariance*T';
 end
 b.cost(m,k)=r.cost;b.iterations(m,k)=r.iterations;b.closure(m,k)=r.constraint_inf;
 b.stationarity(m,k)=r.stationarity_norm;b.physical(m,k)=r.physical_valid;
 b.active_bound(m,k)=r.active_parameter_bound;b.rank(m,k)=r.rank;
 b.condition_scaled(m,k)=r.condition_scaled;b.elapsed(m,k)=r.elapsed_seconds;
 b.selected_candidate(m,k)=r.selected_candidate;b.reprojection(:,:,m,k)=r.raw_reprojection;
 b.adjusted(:,:,m,k)=r.adjusted_observations;b.correction(:,:,m,k)=r.observation_correction;
 if ~isempty(r.sensitivity),b.sensitivity(:,:,m,k)=r.sensitivity;end
 a=numel(b.latent_values);b.latent_offset(:,m,k)=[a+1;numel(r.latent_error)];
 b.latent_values=[b.latent_values;r.latent_error];
 a=size(b.history_values,1);b.history_offset(:,m,k)=[a+1;size(r.history,1)];
 if ~isempty(r.history),b.history_values=[b.history_values;r.history];end
 [b,code]=jog2.Batch.status(b,r.status);b.status_code(m,k)=code;
 for j=1:numel(r.candidates)
  c=r.candidates{j};a=size(b.candidate_history,1);
  b.candidate_history_offset(:,end+1)=[a+1;size(c.history,1)];
  if ~isempty(c.history),b.candidate_history=[b.candidate_history;c.history];end
  b.candidate_camera(:,end+1)=jog2.Util.camvec(c.camera);
  ph=NaN;if isfield(c,'physical_valid'),ph=double(c.physical_valid);end
  b.candidate_info(:,end+1)=[m;b.trial_id(k);j;c.success;c.cost;c.iterations;c.constraint_inf;ph;r.selected_candidate==j];
  [b,code]=jog2.Batch.status(b,c.status);b.candidate_status_code(end+1)=code;
 end
end
function [b,c]=status(b,s)
 c=find(strcmp(b.meta.status_dictionary,s),1);
 if isempty(c),b.meta.status_dictionary{end+1}=s;c=numel(b.meta.status_dictionary);end
end
end
end
