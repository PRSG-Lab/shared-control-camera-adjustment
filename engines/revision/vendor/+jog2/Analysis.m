classdef Analysis
methods(Static)
function s=condition(file,c,cfg)
 started=tic;d=jog2.Store.design(file,c);E=[];CN=[];CC=[];valid=[];cost=[];lin=[];
 branches=[];gap=[];clusters=[];status={};reproj=[];ids=[];
 for j=1:numel(c.batches)
  b=jog2.Store.read(file,c.batches{j});
  if mod(j,10)==0||j==numel(c.batches),fprintf('  Statistics batch %d/%d | %.1f s\n',j,numel(c.batches),toc(started));end
  E=cat(2,E,b.errors);CN=cat(3,CN,b.covariance_native);CC=cat(3,CC,b.covariance_common);
  valid=cat(2,valid,b.valid);cost=cat(2,cost,b.cost);lin=cat(2,lin,b.linear_error);ids=[ids b.trial_id];
  rr=squeeze(sqrt(mean(reshape(b.reprojection,2*d.spec.n,numel(d.methods),[]).^2,1)));
  if numel(d.methods)==1,rr=reshape(rr,1,[]);end;reproj=[reproj rr];
  [bc,bg,cl]=jog2.Analysis.branches(b,d,cfg);branches=[branches bc];gap=[gap bg];clusters=cat(3,clusters,cl);
  for m=1:numel(d.methods),status{m,j}=b.meta.status_dictionary(b.status_code(m,:));end
 end
 [ids,ord]=sort(ids);E=E(:,ord,:);CN=CN(:,:,ord,:);CC=CC(:,:,ord,:);valid=valid(:,ord);
 cost=cost(:,ord);lin=lin(:,ord,:);branches=branches(:,ord);gap=gap(:,ord);reproj=reproj(:,ord);
 N=numel(ids);s=struct('suite',c.suite,'run_id',c.run_id,'spec',c.spec,'methods',{d.methods},...
 'trial_ids',ids,'method',{{}},'geometry',jog2.Util.without(d.geometry,{'master_xyz','master_uv','master_depth_u'}),...
 'nested_diagnostics',{d.nested_diagnostics});
 blocks={1:3,4:6,7,8,9:10,1:6,1:10};names={'position','rotation','log_f','kappa','principal_point','eop','full'};
 for m=1:numel(d.methods)
  e=E(:,:,m);sn=CN(:,:,:,m);sc=CC(:,:,:,m);ok=valid(m,:)&all(isfinite(e),1);
  a=struct('label',d.methods{m},'n_total',N,'n_valid',nnz(ok),'blocks',struct(),...
    'cost',cost(m,:),'reprojection_rmse',reproj(m,:),'branch_count',branches(m,:),...
    'candidate_cost_gap',gap(m,:),'cluster_counts_sensitivity',clusters(:,m,:),...
    'metric_scale',cfg.solver.parameter_scale);
  for z=1:numel(blocks)
   ix=blocks{z};summary=jog.Core.summarize(e(ix,:),sc(ix,ix,:),ok,cfg.nominal);
   native=jog.Core.summarize(-e(ix,:),sn(ix,ix,:),ok,cfg.nominal);
   fs={'nees','coverage_conditional','coverage_operational','coverage_wilson','n_covariance_valid'};
   for f=1:numel(fs),summary.(fs{f})=native.(fs{f});end
   summary.scatter=sqrt(trace(summary.covariance));summary.predicted_scatter=sqrt(trace(summary.mean_predicted_covariance));
   summary.nees_mean=mean(summary.nees(isfinite(summary.nees)));
   summary.nees_quantiles=arrayfun(@(p)jog.Core.quantile(summary.nees,p),[.5 .9 .95 .99]);
   a.blocks.(names{z})=summary;
  end
  C0=d.oracle_reference{m}.nominal_covariance;Ct=d.oracle_reference{m}.actual_sampling_covariance;
  a.linear=jog.Core.summarize(lin(:,:,m),C0,true(1,N),cfg.nominal);
  a.actual_fixed_nominal=jog.Core.summarize(e,C0,ok,cfg.nominal);
  a.actual_fixed_sampling=jog.Core.summarize(e,Ct,ok,cfg.nominal);
  a.linear_sampling=jog.Core.summarize(lin(:,:,m),Ct,true(1,N),cfg.nominal);
  rem=e-lin(:,:,m);L=chol((Ct+Ct')/2,'lower');
  a.remainder=struct('raw_rms',NaN,'normalized_rms',NaN,'per_map_squared',nan(1,N),...
   'reference','true sampling covariance at this epsilon','conditioning','valid fit');
  if any(ok)
   a.remainder.raw_rms=sqrt(mean(sum(rem(:,ok).^2,1)));
   a.remainder.per_map_squared(ok)=sum((L\rem(:,ok)).^2,1);
   a.remainder.normalized_rms=sqrt(mean(a.remainder.per_map_squared(ok)));
  end
  a.bias_decomposition=struct();a.generalized=struct();
  if nnz(ok)>=2
   x=e(:,ok);mu=mean(x,2);S=cov(x');C=chol(C0,'lower');MSE=x*x'/size(x,2);
   bias=sum((C\mu).^2);scatter=(size(x,2)-1)/size(x,2)*trace(C\S/C');
   total=mean(sum((C\x).^2,1));
   a.bias_decomposition=struct('bias',mu,'bias_standard_error',sqrt(diag(S)/size(x,2)),...
    'centered_covariance',S,'MSE',MSE,'bias_nees',bias,'scatter_nees',scatter,...
    'mean_fixed_nees',total,'identity_error',abs(total-bias-scatter));
   D=diag(cfg.solver.parameter_scale);Sa=D\S/D;Ca=D\a.blocks.full.mean_predicted_covariance/D;
   [R,p]=chol((Ca+Ca')/2,'lower');
   if p==0
    W=R\Sa/R';[vec,ev]=eig((W+W')/2);[lam,ix]=sort(diag(ev),'descend');v=R'\vec(:,ix);
    v=v./sqrt(sum(v.^2,1));energy=zeros(5,10);
    for bb=1:5,energy(bb,:)=sum(v(blocks{bb},:).^2,1);end
    a.generalized=struct('covariance_eigenvalues',lam,'dimensionless_contrasts',v,...
      'block_coefficient_shares',energy,'metric',cfg.solver.parameter_scale,...
      'interpretation','contrast coefficients, not invariant physical variance shares');
   end
  end
  nu=2*d.spec.n-10;vf=2*cost(m,:)/nu;good=ok&isfinite(vf);
  reject=(2*cost(m,:)<jog.Core.chi2(.025,nu)|2*cost(m,:)>jog.Core.chi2(.975,nu))&good;
  a.variance_factor=struct('values',vf,'df',nu,'mean',mean(vf(good)),...
   'quantiles',arrayfun(@(p)jog.Core.quantile(vf(good),p),[.25 .5 .75 .95]),...
   'rejection_rate',sum(reject)/max(1,nnz(good)),'rejection_wilson',jog.Core.wilson(sum(reject),nnz(good)),...
   'n_valid',nnz(good),'known_absolute_scale',1,'covariance_rescaled',false);
  a.variance_components=jog2.Analysis.components(d,m);
  s.method{m}=a;
 end
 if isfield(d,'similarity'),s.similarity=d.similarity;end
end
function [count,gap,counts]=branches(b,d,cfg)
 M=numel(d.methods);N=numel(b.trial_id);count=zeros(M,N);gap=nan(M,N);counts=zeros(9,M,N);
 for m=1:M
  for k=1:N
   sel=find(b.candidate_info(1,:)==m&b.candidate_info(2,:)==b.trial_id(k)&b.candidate_info(4,:)>0);
   [~,ord]=sort(b.candidate_info(5,sel));sel=sel(ord);nc=numel(sel);dist=zeros(nc);
   for a=1:nc
    ca=jog2.Util.vecCam(b.candidate_camera(:,sel(a)),d.geometry.truth_camera.scale);
    for z=a+1:nc
     cz=jog2.Util.vecCam(b.candidate_camera(:,sel(z)),d.geometry.truth_camera.scale);
     dist(a,z)=norm(jog.Camera.error(ca,cz)./cfg.solver.parameter_scale);dist(z,a)=dist(a,z);
    end
   end
   costs=b.candidate_info(5,sel);if nc>1,gap(m,k)=costs(2)-costs(1);end
   pos=0;
   for tol=cfg.analysis.cluster_distance
    for ct=cfg.analysis.cluster_cost
     pos=pos+1;groups={};
     for a=1:nc
      placed=false;
      for gr=1:numel(groups)
       ix=groups{gr};
       if all(dist(a,ix)<=tol)&&all(abs(costs(a)-costs(ix))<=ct*max(1,abs(costs(a))))
        groups{gr}(end+1)=a;placed=true;break;
       end
      end
      if ~placed,groups{end+1}=a;end
     end
     counts(pos,m,k)=numel(groups);
    end
   end
   count(m,k)=counts(5,m,k);
  end
 end
end
function out=components(d,m)
 no=d.noise_model;W=d.oracle_reference{m}.sensitivity;n=d.spec.n;
 Qi=zeros(5*n);Qx=Qi;
 for i=1:n,a=5*i-4:5*i-3;b=5*i-2:5*i;Qi(a,a)=no.Q_local(a,a);Qx(b,b)=no.Q_local(b,b);end
 C={W*Qi*W',W*Qx*W'};names={'image','local_XYZ'};sumc=C{1}+C{2};
 for k=1:numel(no.components)
  ix=no.components{k}.columns;G=no.G_raw(:,ix);q=no.Q_b(ix,ix);
  cc=W*G*q*G'*W';C{end+1}=cc;names{end+1}=no.components{k}.name;sumc=sumc+cc;
 end
 actual=d.oracle_reference{m}.actual_sampling_covariance;
 out=struct('names',{names},'covariance',{C},'sum_error',jog.Core.relative(sumc,actual),...
 'reference_local',d.decomposition.N_local_inverse,...
 'optimal_shared_increment',d.decomposition.Gamma*d.decomposition.Q_b_given_r*d.decomposition.Gamma');
end
function p=population(o)
 p=struct('conditions',{{}},'paired_differences',{{}});
 sel=find(cellfun(@(c)strcmp(c.suite,'J12'),o.conditions));if isempty(sel),return;end
 labels=o.summaries{sel(1)}.methods;cfg=o.config;
 for regime=1:size(cfg.j12.regimes,1)
  ix=sel(cellfun(@(c)c.spec.x==regime,o.conditions(sel)));v=nan(numel(ix),numel(labels));
  ids=zeros(size(ix));wilsonUpper=nan(size(v));conditional=nan(size(v));
  for g=1:numel(ix),s=o.summaries{ix(g)};ids(g)=s.spec.geometry_id;
   for m=1:numel(labels),z=find(s.method{m}.blocks.full.nominal==.95);v(g,m)=s.method{m}.blocks.full.coverage_operational(z);conditional(g,m)=s.method{m}.blocks.full.coverage_conditional(z);wilsonUpper(g,m)=s.method{m}.blocks.full.coverage_wilson(z,2);end
  end
  boot=nan(cfg.analysis.bootstrap,size(v,2));r=jog2.Util.analysisStream(cfg,regime,0);
  for b=1:size(boot,1),sample=randi(r,size(v,1),1,size(v,1));boot(b,:)=mean(v(sample,:),1,'omitnan');end
  p.conditions{end+1}=struct('regime',regime,'geometry_ids',ids,'methods',{labels},'coverage',v,...
   'conditional_coverage',conditional,'fraction_wilson_upper_below90',mean(wilsonUpper<.9,1),...
   'minimum',min(v,[],1),'maximum',max(v,[],1),'mean',mean(v,1,'omitnan'),'median',median(v,1,'omitnan'),'q25',arrayfun(@(m)jog.Core.quantile(v(:,m),.25),1:size(v,2)),...
   'q75',arrayfun(@(m)jog.Core.quantile(v(:,m),.75),1:size(v,2)),...
   'fraction_observed_below90',mean(v<.9,1),'cluster_bootstrap_means',boot,...
   'cluster_ci',[arrayfun(@(m)jog.Core.quantile(boot(:,m),.025),1:size(v,2));...
   arrayfun(@(m)jog.Core.quantile(boot(:,m),.975),1:size(v,2))]);
 end
 if ~isempty(p.conditions)
  base=p.conditions{1};
  for rr=2:numel(p.conditions)
   other=p.conditions{rr};[ids,ia,ib]=intersect(base.geometry_ids,other.geometry_ids);
   delta=other.coverage(ib,:)-base.coverage(ia,:);boot=zeros(cfg.analysis.bootstrap,size(delta,2));
   rs=jog2.Util.analysisStream(cfg,80+rr,0);
   for b=1:size(boot,1),draw=randi(rs,numel(ids),1,numel(ids));boot(b,:)=mean(delta(draw,:),1,'omitnan');end
   ci=[arrayfun(@(m)jog.Core.quantile(boot(:,m),.025),1:size(delta,2));...
       arrayfun(@(m)jog.Core.quantile(boot(:,m),.975),1:size(delta,2))];
   p.paired_differences{end+1}=struct('reference_regime',1,'regime',rr,'geometry_ids',ids,...
    'differences',delta,'mean',mean(delta,1,'omitnan'),'cluster_ci',ci,'bootstrap_means',boot);
  end
 end
end
end
end
