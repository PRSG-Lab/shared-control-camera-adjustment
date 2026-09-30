function [manifest,figure_data]=jog_make_figures_v2(file,mode,assets)
%JOG_MAKE_FIGURES_V2 Re-render F01-F15 directly from saved MAT, no solver.
if nargin<2,mode='paper';end
if nargin<3,assets={};end
if ischar(assets)||isstring(assets),assets=cellstr(assets);end
o=jog2.Store.metadata(file);dest=fullfile(fileparts(file),'figures');
manifest=struct([]);figure_data=struct();E=struct();
if ~isempty(assets),manifest=o.figure_manifest;figure_data=o.figure_data;end
names=fieldnames(o.legacy);
for i=1:numel(names)
 if isempty(regexp(names{i},'^J0[0-8]$','once')),continue;end
 E.(names{i})=jog2.Store.read(file,o.legacy.(names{i}));
end
if strcmp(mode,'legacy')
 old=jog2.LegacyView.make(file,o,E);
 [manifest,figure_data]=jog_make_figures(old,fullfile(dest,'legacy'));
 o.legacy_figure_manifest=manifest;o.legacy_figure_data=figure_data;jog2.Store.saveMetadata(file,o);
 return;
end
if isfield(E,'J01')
 cs=E.J01.conditions;p=jog2.Plot.panel('Shared mode','IOP model');p.type='heat';
 p.matrix=cell2mat(cellfun(@(x)log10(1+x.design.learning_spectrum(:)'),cs,'UniformOutput',false)');
 p.ylabels=cellfun(@(x)x.name,cs,'UniformOutput',false);
 q=jog2.Plot.panel('IOP model','Analytical position scatter (m)');q.xlabels=p.ylabels;
 q=jog2.Plot.curve(q,1:numel(cs),cellfun(@(x)sqrt(trace(x.design.Sigma(1:3,1:3))),cs),'Full covariance');
 q=jog2.Plot.curve(q,1:numel(cs),cellfun(@(x)sqrt(trace(x.design.N_local_inverse(1:3,1:3))),cs),'No-shared reference');
 emit('F01',{p,q},'Truth-design analytical residual information log10(1+eigenvalue) and position scatter; J01, n=40. These are not empirical fits.');
end
if all(isfield(E,{'J02','J04','J05'}))
 p=jog2.Plot.panel('Information s','Target standard deviation','logx');
 for r=o.config.linear.rho
  c=E.J02.conditions(cellfun(@(a)a.rho==r,E.J02.conditions));x=cellfun(@(a)a.s,c);
  p=jog2.Plot.curve(p,x,cellfun(@(a)sqrt(a.design.Sigma(1,1)),c),sprintf('Theory rho %.1f',r));
  p=jog2.Plot.curve(p,x,cellfun(@(a)a.summary.std(1),c),sprintf('Empirical rho %.1f',r));
 end
 c=E.J04.conditions;x=cellfun(@(a)a.tau,c);q=jog2.Plot.panel('Added hidden variance tau','Variance / mean residual energy');
 q=jog2.Plot.curve(q,x,cellfun(@(a)a.design.Sigma(1,1),c),'Target variance theory');
 q=jog2.Plot.curve(q,x,cellfun(@(a)a.summary.covariance(1,1),c),'Target variance empirical');
 q=jog2.Plot.curve(q,x,cellfun(@(a)mean(a.residual_energy),c),'Paired residual energy');
 r=jog2.Plot.panel('Information s','Normalized absorption ratio','logx');
 t=jog2.Plot.panel('Information s','Target variance','logxlogy');
 for a=o.config.linear.rates
  c=E.J05.conditions(cellfun(@(x)x.rate==a,E.J05.conditions));x=cellfun(@(z)z.s,c);
  r=jog2.Plot.curve(r,x,cellfun(@(z)z.EAR,c),sprintf('a %.2f',a));
  t=jog2.Plot.curve(t,x,cellfun(@(z)z.design.Sigma(1,1),c),sprintf('Theory a %.2f',a));
  t=jog2.Plot.curve(t,x,cellfun(@(z)z.summary.covariance(1,1),c),sprintf('Empirical a %.2f',a));
 end
 emit('F02',{p,q,r,t},'J02/J04/J05: finite-design theory and independent-map Monte Carlo. Residual invariance and absorption ratio do not imply vanishing uncertainty.');
end
if all(isfield(E,{'J06','J07'}))
 cs=E.J06.conditions;x=cellfun(@(c)c.spread,cs);p=jog2.Plot.panel('Relative full depth width','Residual information J','logx');
 p=jog2.Plot.curve(p,x,cellfun(@(c)c.known_f.J,cs),'Known focal');
 p=jog2.Plot.curve(p,x,cellfun(@(c)c.free_f.J,cs),'Free focal (zero analytically)');
 q=jog2.Plot.panel('Relative full depth width','Position scatter (m)','logx');
 q=jog2.Plot.curve(q,x,cellfun(@(c)sqrt(c.known_f.Sigma(1,1)),cs),'Known focal');
 q=jog2.Plot.curve(q,x,cellfun(@(c)sqrt(c.free_f.Sigma(1,1)),cs),'Free focal');
 [r,t]=planePanels(E.J07,'points_per_plane');
 emit('F03',{p,q,r,t},'J06 analytical directional depth-scale absorption and J07 Gaussian sufficient-statistic Monte Carlo. Fallbacks retained in unconditional moments.');
end
if isfield(E,'J07')
 [p,q]=planePanels(E.J07,'independent_planes');[r,t]=planePanels(E.J07,'relative_depth_spread');
 emit('F04',{p,r,q,t},'J07 independent plane count and depth diversity. Finite scatter versus limiting covariance; density within a plane is different from independent information.');
end
ix=select(o,'J09','noise_scale');
if ~isempty(ix)
 emit('F05',{metric(o,ix,'position','scatter','Noise multiplier','Position scatter (m)'),...
  metric(o,ix,'position','coverage','Noise multiplier','Position coverage')},...
  'J09 baseline geometry noise sweep. Scatter is centered; coverage uses nominal 95% regions with Wilson intervals. Failed fits remain in operational coverage stored in MAT.');
end
ix=select(o,'J09','depth_spread');base=select(o,'J09','noise_scale');base=base(cellfun(@(x)x.spec.noise_scale==1,o.summaries(base)));
if ~isempty(ix)
 ix=[base ix];emit('F06',{joint(o,ix,'depth_spread','Relative full depth width'),...
 joint(o,[base select(o,'J09','point_count')],'n','Control point count'),...
 failurePanel(o,ix,'depth_spread','Relative full depth width'),...
 failurePanel(o,[base select(o,'J09','point_count')],'n','Control point count')},...
 'J09 GH_FULL 3D/6D/10D coverage. Legacy geometries differ across depth/count, so this plot is conditional on those geometries.');
end
panels={};
if isfield(E,'J08'),[p,q]=planePanels(E.J08,'global_datum_std');panels={p,q};end
ix=select(o,'J09','global_translation');
if ~isempty(ix),panels{end+1}=metric(o,ix,'position','coverage','Point count','Position coverage');end
if ~isempty(panels),emit('F07',panels,'Global datum: reduced-model position/focal scatter and full-camera position coverage. Same-map estimates may agree while reported uncertainty differs.');end
ix=select(o,'J10','');
if ~isempty(ix)
 p=jog2.Plot.panel('Noise standard-deviation multiplier','Full 10D coverage','logx');p.reference=.95;
 q=jog2.Plot.panel('Noise standard-deviation multiplier','Position coverage','logx');q.reference=.95;
 r=jog2.Plot.panel('Noise standard-deviation multiplier','Normalized remainder RMS','logxlogy');
 t=jog2.Plot.panel('Noise standard-deviation multiplier','10D coverage (narrow geometry)','logx');t.reference=.95;
 gids=unique(cellfun(@(a)a.spec.geometry_id,o.summaries(ix)));
 for g=gids
  jj=ix(cellfun(@(a)a.spec.geometry_id==g,o.summaries(ix)));[x,ord]=sort(cellfun(@(a)a.spec.noise_scale,o.summaries(jj)));jj=jj(ord);
  [y,l,h]=values(o,jj,'GH_FULL','full','coverage');p=jog2.Plot.curve(p,x,y,sprintf('Geometry %d',g),l,h);
  [y,l,h]=values(o,jj,'GH_FULL','position','coverage');q=jog2.Plot.curve(q,x,y,sprintf('Geometry %d',g),l,h);
  y=cellfun(@(a)getmethod(a,'GH_FULL').remainder.normalized_rms,o.summaries(jj));r=jog2.Plot.curve(r,x,y,sprintf('Geometry %d',g));
  if g==3
   for typ={'linear_sampling','actual_fixed_sampling','blocks'}
    yy=[];for z=jj,a=getmethod(o.summaries{z},'GH_FULL');if strcmp(typ{1},'blocks'),ss=a.blocks.full;else,ss=a.(typ{1});end;yy(end+1)=ss.coverage_conditional(ss.nominal==.95);end
    t=jog2.Plot.curve(t,x,yy,typ{1});
   end
   y0=y(find(isfinite(y)&y>0,1));if ~isempty(y0),r=jog2.Plot.curve(r,x,x/x(1)*y0,'Slope 1 reference (not acceptance test)');end
  end
 end
 emit('F08',{p,q,r,t},'J10 paired noise sweeps on fixed geometries. All local/shared standard deviations scale together. Remainder is conditional on valid fits and whitened at each noise scale; slope 1 is a reference only.');
end
ix=select(o,'J11','');
if ~isempty(ix)
 panels={};
 for ci=ix
  ss=o.summaries{ci};pp={methodPanel(ss,'full'),methodPanel(ss,'position')};
  if any(strcmp(ss.spec.sweep,{'M1','M4'})),panels=[panels pp];
  else,emit(['S03_' ss.spec.sweep],pp,'J11 optional structural misspecification: full/position conditional coverage with Wilson intervals.');end
  p=jog2.Plot.panel('Assumed covariance','Position scatter (m)');p.xlabels=ss.methods;
  y=cellfun(@(a)a.blocks.position.scatter,ss.method);pred=cellfun(@(a)a.blocks.position.predicted_scatter,ss.method);
  p=jog2.Plot.curve(p,1:numel(y),y,'Empirical scatter');p=jog2.Plot.curve(p,1:numel(y),pred,'Predicted scatter');
  q=jog2.Plot.panel('Assumed covariance','Global rejection / linear 10D coverage');q.xlabels=ss.methods;
  y=cellfun(@(a)a.variance_factor.rejection_rate,ss.method);q=jog2.Plot.curve(q,1:numel(y),y,'Global rejection');
  y=cellfun(@(a)a.linear.coverage_conditional(a.linear.nominal==.95),ss.method);q=jog2.Plot.curve(q,1:numel(y),y,'First-order nominal coverage');
  emit(['S03_' ss.spec.sweep '_size'],{p,q},'J11 covariance size and residual rejection versus first-order nominal coverage. Same observations and initializer pool within each condition.');
 end
 emit('F09',panels,'J11 M1/M4 core covariance misspecification. M1 multipliers act on Q_b variance. True generating noise stays fixed within each condition; structural extensions are S03 assets.');
end
if isfield(o.diagnostics,'geometry_population')&&~isempty(o.diagnostics.geometry_population.conditions)
 pp=o.diagnostics.geometry_population;p=jog2.Plot.panel('Geometry ID','Operational full coverage');p.reference=.95;
 for i=1:numel(pp.conditions)
  a=pp.conditions{i};m=find(strcmp(a.methods,'GH_FULL'),1);if isempty(m),continue;end
  p=jog2.Plot.curve(p,a.geometry_ids,a.coverage(:,m),sprintf('Regime %d',a.regime));
 end
 q=jog2.Plot.panel('Geometry ID','Paired coverage difference');q.reference=0;
 for k=1:numel(pp.paired_differences),a=pp.paired_differences{k};q=jog2.Plot.curve(q,a.geometry_ids,a.differences(:,m),sprintf('Regime %d minus 1',a.regime));end
 r=jog2.Plot.panel('Regime','Mean coverage / cluster bootstrap CI');r.reference=.95;
 for mm=1:numel(pp.conditions{1}.methods)
  y=cellfun(@(a)a.mean(mm),pp.conditions);lo=cellfun(@(a)a.cluster_ci(1,mm),pp.conditions);hi=cellfun(@(a)a.cluster_ci(2,mm),pp.conditions);
  r=jog2.Plot.curve(r,1:numel(y),y,pp.conditions{1}.methods{mm},lo,hi);
 end
 emit('F10',{p,q,r},'J12 per-geometry coverage. Geometry is the clustering unit; pooled maps are not identical independent Bernoulli replicates. Cluster bootstrap summaries are saved.');
end
ix=select(o,'J09','');if isempty(ix),ix=select(o,'J10','');end
if ~isempty(ix)
 p=jog2.Plot.panel('Condition index','Variance factor median / IQR');p.reference=1;
 q=jog2.Plot.panel('Condition index','Global-test rejection rate');q.reference=.05;
 for name={'GH_LOCAL','GH_FULL'}
  y=[];r=[];lo=[];hi=[];vlo=[];vhi=[];
  for k=ix
   a=getmethod(o.summaries{k},name{1});y(end+1)=a.variance_factor.quantiles(2);vlo(end+1)=a.variance_factor.quantiles(1);vhi(end+1)=a.variance_factor.quantiles(3);r(end+1)=a.variance_factor.rejection_rate;
   lo(end+1)=a.variance_factor.rejection_wilson(1);hi(end+1)=a.variance_factor.rejection_wilson(2);
  end
  p=jog2.Plot.curve(p,1:numel(ix),y,name{1},vlo,vhi);q=jog2.Plot.curve(q,1:numel(ix),r,name{1},lo,hi);
 end
 t=jog2.Plot.panel('Condition index','Position coverage');t.reference=.95;
 for name=o.summaries{ix(1)}.methods
  [y,l,h]=values(o,ix,name{1},'position','coverage');t=jog2.Plot.curve(t,1:numel(ix),y,name{1},l,h);
 end
 more={p,q,t};
 if isfield(o.diagnostics,'J04_variance_factor')
  vf=o.diagnostics.J04_variance_factor;t=jog2.Plot.panel('Added hidden variance tau','Mean variance factor (df=2)');t.reference=1;
  t=jog2.Plot.curve(t,cellfun(@(a)a.tau,vf),cellfun(@(a)a.mean,vf),'J04 paired residual statistic');
  more{end+1}=t;
 end
 emit('F11',more,'D02: IQR bars describe the distribution, Wilson bars describe rejection-rate uncertainty. variance factor = 2 cost/(2n-10). Known absolute covariance is never residual-rescaled. Two-sided 5% chi-square test is approximate for nonlinear fits.');
 s=o.summaries{ix(min(3,numel(ix)))};p=methodPanel(s,'full');q=jog2.Plot.panel('Chi-square(10) quantile','Empirical NEES quantile');
 r=jog2.Plot.panel('Method','Fixed-C mean NEES contribution');r.xlabels=s.methods;
 y=[];z=[];
 for m=1:numel(s.method)
  a=s.method{m};v=sort(a.blocks.full.nees(isfinite(a.blocks.full.nees)));N=numel(v);
  q=jog2.Plot.curve(q,jog.Core.chi2(((1:N)-.5)/max(1,N),10),v,a.label);
  if isempty(fieldnames(a.bias_decomposition)),y(m)=NaN;z(m)=NaN;else,y(m)=a.bias_decomposition.bias_nees;z(m)=a.bias_decomposition.scatter_nees;end
 end
 r=jog2.Plot.curve(r,1:numel(y),y,'Bias');r=jog2.Plot.curve(r,1:numel(z),z,'Centered scatter');
 t=jog2.Plot.panel('Block','Method');t.type='heat';bn={'position','rotation','log_f','kappa','principal_point','eop','full'};
 mat=nan(numel(s.methods),numel(bn));for m=1:size(mat,1),for b=1:size(mat,2),aa=s.method{m}.blocks.(bn{b});mat(m,b)=aa.coverage_conditional(aa.nominal==.95);end,end
 t.matrix=mat;t.xlabels=bn;t.ylabels=s.methods;t.reference=[0 1];
 emit('F12',{p,q,r,t},'D01/D03 representative condition. Full and block coverage, NEES QQ, fixed-C bias/scatter decomposition. Log-f intervals can be exponentiated; mixed-unit contrast coefficients are not physical variance shares.');
end
ix=select(o,'J09','');
if ~isempty(ix)
 p=jog2.Plot.panel('Condition index','Mean successful branch count');
 q=jog2.Plot.panel('Condition index','Median second-best cost gap');
 for name={'GH_LOCAL','GH_FULL'}
  y=cellfun(@(a)mean(getmethod(a,name{1}).branch_count),o.summaries(ix));p=jog2.Plot.curve(p,1:numel(ix),y,name{1});
  y=cellfun(@(a)median(getmethod(a,name{1}).candidate_cost_gap,'omitnan'),o.summaries(ix));q=jog2.Plot.curve(q,1:numel(ix),y,name{1});
 end
 s=o.summaries{ix(min(3,numel(ix)))};a=getmethod(s,'GH_FULL');r=jog2.Plot.panel('Ordered contrast','Variance ratio');
 t=jog2.Plot.panel('Parameter block','Leading contrast coefficient share');
 if ~isempty(fieldnames(a.generalized))
  r=jog2.Plot.curve(r,1:10,a.generalized.covariance_eigenvalues,'Empirical / mean predicted');
  t.xlabels={'position','rotation','log_f','kappa','principal_point'};
  t=jog2.Plot.curve(t,1:5,a.generalized.block_coefficient_shares(:,1),'Leading contrast');
 end
 emit('S01',{p,q,r,t},'D01/D03: complete-link multistart diagnostics and representative GH_FULL generalized contrasts. Candidate thresholds and dimensionless parameter scale are saved. Coefficient shares are metric-dependent, not physical variance shares.');
 panels={};chosen=ix(cellfun(@(a)a.spec.noise_scale==1&&~strcmp(a.spec.kind,'global'),o.summaries(ix)));
 for jj=chosen
  s=o.summaries{jj};p=jog2.Plot.panel('Number of free camera parameters','Analytical position scatter (m)');q=jog2.Plot.panel('Number of free camera parameters','Position variance inflation');
  dd=s.nested_diagnostics;x=cellfun(@(a)numel(a.parameter_columns),dd);
  p=jog2.Plot.curve(p,x,cellfun(@(a)sqrt(trace(a.Sigma(1:3,1:3))),dd),'Full covariance');
  p=jog2.Plot.curve(p,x,cellfun(@(a)sqrt(trace(a.N_local_inverse(1:3,1:3))),dd),'No-shared reference');
  q=jog2.Plot.curve(q,x,cellfun(@(a)a.position_inflation,dd),'Max directional variance ratio');
  emit(sprintf('S02_J09c%03d',s.spec.condition_id),{p,q},sprintf('D04 exact J09 truth geometry: n=%d, relative full depth width=%g; analytical nested 6/7/8/10 parameter designs, not nonlinear Monte Carlo.',s.spec.n,s.spec.depth_spread));
 end
end
ix=select(o,'J13','');
if ~isempty(ix)
 panels={};rots=unique(cellfun(@(a)a.spec.x,o.summaries(ix)));
 for rot=rots
  jj=ix(cellfun(@(a)a.spec.x==rot,o.summaries(ix)));[n,ord]=sort(cellfun(@(a)a.spec.n,o.summaries(jj)));jj=jj(ord);
  p=jog2.Plot.panel('Control point count','Position scatter (m)');p.subtitle=sprintf('Rotation STD %.3g deg',rot);
  for name={'GH_LOCAL','GH_FULL'}
   [y,~,~]=values(o,jj,name{1},'position','scatter');p=jog2.Plot.curve(p,n,y,name{1});
   [y,~,~]=values(o,jj,name{1},'position','predicted_scatter');p=jog2.Plot.curve(p,n,y,[name{1} ' predicted']);
  end
  p=jog2.Plot.curve(p,n,cellfun(@(a)sqrt(trace(a.similarity.shared_covariance(1:3,1:3))),o.summaries(jj)),'Analytical shared floor');
  q=jog2.Plot.panel('Control point count','GH_FULL coverage');q.subtitle=sprintf('Rotation STD %.3g deg',rot);q.reference=.95;
  for block={'eop','log_f','kappa','principal_point','full'},[y,l,h]=values(o,jj,'GH_FULL',block{1},'coverage');q=jog2.Plot.curve(q,n,y,block{1},l,h);end
  panels=[panels {p,q}];
 end
 emit('F13',panels,'J13 shared seven-parameter similarity loading. Separate rotation STD panels; same 60-point pivot for nested n. Shared position term is a first-order datum floor. EOP and IOP marginal calibration are distinguished.');
end
ix=select(o,'J14','');
if ~isempty(ix)
 p=metric(o,ix,'position','coverage','Scenario','Position coverage');q=metric(o,ix,'full','coverage','Scenario','Full coverage');
 r=jog2.Plot.panel('Scenario','Position variance contribution (m^2)');
 comps={'image','local_XYZ','patch','global'};
 for j=1:numel(comps)
  y=nan(size(ix));for k=1:numel(ix),a=getmethod(o.summaries{ix(k)},'GH_FULL');cc=a.variance_components;z=find(strcmp(cc.names,comps{j}));if ~isempty(z),y(k)=trace(cc.covariance{z}(1:3,1:3));end,end
  r=jog2.Plot.curve(r,1:numel(ix),y,comps{j});
 end
 t=metric(o,ix,'position','scatter','Scenario','Position scatter (m)');
 emit('F14',{t,p,q,r},'J14 S1-S3 noise-strength sensitivity. Component curves sum to the same-estimator linear sampling covariance; LOCAL/FULL efficiency difference is not the shared-error contribution.');
end
ti=find(cellfun(@(s)isfield(s,'targets'),o.summaries));
if ~isempty(ti)
 % First representative and first narrow-depth source, all data remain in MAT.
 base=ti(cellfun(@(s)s.spec.n==30&&s.spec.depth_spread==.15&&s.spec.noise_scale==1,o.summaries(ti)));
 chosen=ti(1);if ~isempty(base),chosen=base(1);end;weak=ti(cellfun(@(s)s.spec.depth_spread==.02,o.summaries(ti)));if ~isempty(weak),chosen=unique([chosen weak(1)]);end
 for z=1:numel(chosen)
  s=o.summaries{chosen(z)};m=find(strcmp(s.methods,'GH_FULL'),1);if isempty(m),m=1;end;panels={};
  for kind={'plane','image'}
   for field={'rmse','coverage'}
    p=jog2.Plot.panel('Grid column','Grid row');p.type='heat';v=s.targets.(kind{1}).(field{1})(:,m);
    p.matrix=reshape(v,s.targets.targets.grid_size,[]);if strcmp(field{1},'coverage'),p.reference=[0 1];end
    p.ylabel=[kind{1} ' ' field{1}];panels{end+1}=p;
   end
  end
  asset='F15';if z>1,asset=sprintf('F15_case%d',z);end
  emit(asset,panels,sprintf('J15 %s condition %d, %s: plane RMSE(m)/coverage and image RMSE(px)/coverage. Exact external plane/checkpoints; pointwise 2D regions, 25 correlated targets per camera map.',s.suite,s.spec.condition_id,s.methods{m}));
  for kind={'plane','image'}
   name=kind{1};pp={};lim=max(s.targets.(name).rmse(:));if ~isfinite(lim)||lim<=0,lim=1;end
   for mi=1:numel(s.methods)
    for field={'rmse','coverage'}
     p=jog2.Plot.panel('Grid column',[name ' ' field{1} ' ' s.methods{mi}]);p.type='heat';
     p.matrix=reshape(s.targets.(name).(field{1})(:,mi),s.targets.targets.grid_size,[]);
     if strcmp(field{1},'coverage'),p.reference=[0 1];else,p.reference=[0 lim];end
     pp{end+1}=p;
    end
    % Separate method files keep labels readable, with common limits.
    emit([asset '_' name '_' s.methods{mi}],pp,sprintf('J15 %s: common RMSE color range across methods; coverage uses 2D pointwise ellipses. Camera maps, not targets, are independent units.',name));pp={};
   end
   p=jog2.Plot.panel('Grid column',[name ' variance inflation']);p.type='heat';p.matrix=reshape(s.targets.inflation.(name),s.targets.targets.grid_size,[]);
   q=jog2.Plot.panel('Target error coordinate 1','Target error coordinate 2');q.type='ellipse';
   center=ceil(size(s.targets.(name).rmse,1)/2);theta=linspace(0,2*pi,100);circle=[cos(theta);sin(theta)];
   for mi=1:numel(s.methods)
    C=s.targets.(name).predicted_covariance(:,:,center,mi);if any(~isfinite(C(:))),continue;end
    [V,D]=eig((C+C')/2);if any(diag(D)<=0),continue;end
    pts=V*sqrt(D*jog.Core.chi2(.95,2))*circle;q=jog2.Plot.curve(q,pts(1,:),pts(2,:),s.methods{mi});
   end
   emit([asset '_' name '_uncertainty'],{p,q},'Left: truth-design maximum directional variance inflation relative to local-only optimum. Right: illustrative ellipse from mean predicted covariance at central target, centered at zero; not a confidence region for the Monte Carlo mean. Plane units m; image units px.');
  end
 end
end
o.figure_manifest=manifest;o.figure_data=figure_data;o.meta.figure_source_hash=jog2.Util.hash(jsonencode(jog2.Util.sources()));jog2.Store.saveMetadata(file,o);
 function emit(id,panels,caption)
  if ~isempty(assets)&&~ismember(id,assets),return;end
  if ~isempty(manifest),manifest(strcmp({manifest.asset_id},id))=[];end
  [generatedManifest,generatedData]=jog2.Plot.render(id,panels,caption,o,dest);if isempty(manifest),manifest=generatedManifest;else,manifest(end+1)=generatedManifest;end;figure_data.(generatedManifest.data_field)=generatedData;
 end
end
 function ix=select(o,id,sweep)
  ix=find(cellfun(@(s)strcmp(s.suite,id)&&(isempty(sweep)||strcmp(s.spec.sweep,sweep)),o.summaries));
 end
 function [y,lo,hi]=values(o,ix,name,block,what)
  y=[];lo=[];hi=[];
  for k=ix
   a=getmethod(o.summaries{k},name);b=a.blocks.(block);q=find(b.nominal==.95);
   if strcmp(what,'coverage'),y(end+1)=b.coverage_conditional(q);lo(end+1)=b.coverage_wilson(q,1);hi(end+1)=b.coverage_wilson(q,2);
   else,y(end+1)=b.(what);end
  end
 end
 function p=metric(o,ix,block,what,xlab,ylab)
  p=jog2.Plot.panel(xlab,ylab);if isempty(ix),return;end
  x=cellfun(@(a)a.spec.x,o.summaries(ix));[x,ord]=sort(x);ix=ix(ord);
  if strcmp(what,'coverage'),p.reference=.95;end
  methods=o.summaries{ix(1)}.methods;
  for mi=1:numel(methods)
   [y,l,h]=values(o,ix,methods{mi},block,what);p=jog2.Plot.curve(p,x,y,methods{mi},l,h);
   if strcmp(what,'scatter'),[y,~,~]=values(o,ix,methods{mi},block,'predicted_scatter');p=jog2.Plot.curve(p,x,y,[methods{mi} ' predicted']);end
  end
 end
 function p=joint(o,ix,key,xlab)
  p=jog2.Plot.panel(xlab,'Coverage');p.reference=.95;if isempty(ix),return;end
  x=cellfun(@(a)a.spec.(key),o.summaries(ix));[x,ord]=sort(x);ix=ix(ord);
  for name={'position','eop','full'}
   [y,l,h]=values(o,ix,'GH_FULL',name{1},'coverage');p=jog2.Plot.curve(p,x,y,name{1},l,h);
  end
 end

function a=getmethod(s,name)
idx=find(strcmp(s.methods,name),1);assert(~isempty(idx),'Method missing');a=s.method{idx};
end
function p=methodPanel(s,block)
p=jog2.Plot.panel('Assumed method / covariance','Nominal 95% coverage');p.reference=.95;p.xlabels=s.methods;
for kk=1:numel(p.xlabels)
 label=p.xlabels{kk};label=strrep(label,'FULL_alpha_','alpha=');label=strrep(label,'GH_','');label=strrep(label,'FIXED3D_WLS','FIXED3D');label=strrep(label,'FULL_correct','FULL');p.xlabels{kk}=strrep(label,'_',' ');
end
y=[];l=[];h=[];for m=1:numel(s.method),b=s.method{m}.blocks.(block);q=find(b.nominal==.95);y(end+1)=b.coverage_conditional(q);l(end+1)=b.coverage_wilson(q,1);h(end+1)=b.coverage_wilson(q,2);end
p=jog2.Plot.curve(p,1:numel(y),y,[s.spec.sweep ' ' block],l,h);
end
function [p,q]=planePanels(E,sweep)
cs=E.conditions(cellfun(@(c)strcmp(c.spec.sweep,sweep),E.conditions));
p=jog2.Plot.panel(sweep,'Position scatter (m)');q=jog2.Plot.panel(sweep,'Relative focal scatter');
groups=unique(cellfun(@(c)c.spec.region_std,cs));
for sb=groups
 a=cs(cellfun(@(c)c.spec.region_std==sb,cs));x=cellfun(@(c)c.spec.x,a);
 p=jog2.Plot.curve(p,x,cellfun(@(c)c.summary_all_including_fallback.std(1),a),sprintf('Empirical %.2fm',sb));
 p=jog2.Plot.curve(p,x,cellfun(@(c)sqrt(c.floor_covariance(1,1)),a),sprintf('Floor %.2fm',sb));
 q=jog2.Plot.curve(q,x,cellfun(@(c)c.summary_all_including_fallback.std(2)/c.truth(2),a),sprintf('Empirical %.2fm',sb));
 q=jog2.Plot.curve(q,x,cellfun(@(c)sqrt(c.floor_covariance(2,2))/c.truth(2),a),sprintf('Floor %.2fm',sb));
end
end

function p=failurePanel(o,ix,key,label)
p=jog2.Plot.panel(label,'Failure rate');x=cellfun(@(a)a.spec.(key),o.summaries(ix));[x,ord]=sort(x);ix=ix(ord);
for name=o.summaries{ix(1)}.methods
 y=cellfun(@(a)1-getmethod(a,name{1}).n_valid/getmethod(a,name{1}).n_total,o.summaries(ix));p=jog2.Plot.curve(p,x,y,name{1});
end
end
