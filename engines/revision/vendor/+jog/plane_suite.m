function out=plane_suite(id,cfg)
%PLANE_SUITE Exact sufficient-statistic simulation of independent Gaussian
% image/depth observations. No point observations are generated then thrown
% away: lambda_hat and mean depth are the generated data. The complete design,
% common errors, standard normals and statistics are retained in output.mat.
out=struct('id',id,'layer','L2 Gaussian sufficient-statistic pinhole experiment',...
 'conditions',{{}},'notes','');p=cfg.plane;cases={};
if strcmp(id,'J07')
 for sb=p.region_std
  for n=p.n,cases{end+1}=spec('points_per_plane',n,p.depths,sb,0,n);end %#ok<AGROW>
 end
 for d=p.group_counts,cases{end+1}=spec('independent_planes',max(p.n),linspace(10,25,d),p.region_std(1),0,d);end
 for spread=p.depth_spreads,cases{end+1}=spec('relative_depth_spread',max(p.n),20*(1+spread*linspace(-.5,.5,4)),p.region_std(1),0,spread);end
elseif strcmp(id,'J08')
 for sg=p.global_stds,cases{end+1}=spec('global_datum_std',max(p.n),p.depths,p.region_std(1),sg,sg);end
else,error('Unsupported plane experiment');end
for ci=1:numel(cases)
 c=cases{ci};d=numel(c.depths);N=cfg.mc_plane;n=c.n;
 truth=[p.gamma_z;p.f];lambda=p.f./c.depths(:);M=[ones(d,1),1./lambda];
 Sigma=c.region_std^2*eye(d)+c.global_std^2*ones(d);
 H=(M'*(Sigma\M))\(M'/Sigma);floorC=(M'*(Sigma\M))\eye(2);
 weights=(Sigma\ones(d,1))/(ones(1,d)*(Sigma\ones(d,1)));
 floorKnown=1/(ones(1,d)*(Sigma\ones(d,1)));
 Rn=n*p.horizontal_radius^2;
 varLambda=p.image_std^2/Rn*ones(d,1);
 SigmaFinite=Sigma+diag(p.local_depth_std^2/n+(p.f./lambda.^2).^2.*varLambda);
 Cfinite=H*SigmaFinite*H';CfiniteKnown=weights'*SigmaFinite*weights;
 est=nan(2,N);known=nan(1,N);guard=false(1,N);estimateValid=false(1,N);
 lh=zeros(d,N);xd=zeros(d,N);b=zeros(d,N);globalb=zeros(1,N);epsLambda=zeros(d,N);epsDepth=zeros(d,N);
 seeds=zeros(1,N);information=zeros(1,N);reasons=cell(1,N);
 for k=1:N
  seeds(k)=jog.Core.seed(cfg,str2double(id(2:end)),ci,k);rng(seeds(k),'twister');
  b(:,k)=c.region_std*randn(d,1);globalb(k)=c.global_std*randn;
  epsLambda(:,k)=sqrt(varLambda).*randn(d,1);epsDepth(:,k)=p.local_depth_std/sqrt(n)*randn(d,1);
  lh(:,k)=lambda+epsLambda(:,k);xd(:,k)=p.gamma_z+c.depths(:)+b(:,k)+globalb(k)+epsDepth(:,k);
  inRange=all(lh(:,k)>=p.guard_lambda(1) & lh(:,k)<=p.guard_lambda(2));
  if inRange
   Mh=[ones(d,1),1./lh(:,k)];info=Mh'*(Sigma\Mh);information(k)=min(eig((info+info')/2));
   if information(k)>=p.guard_min_information
    est(:,k)=info\(Mh'*(Sigma\xd(:,k)));known(k)=weights'*(xd(:,k)-p.f./lh(:,k));
    guard(k)=true;reasons{k}='accepted';
   else,reasons{k}='guard_rank';end
  else,reasons{k}='guard_magnification';end
  if ~guard(k),est(:,k)=p.fallback;known(k)=p.fallback(1);end
  estimateValid(k)=all(isfinite(est(:,k)));
 end
 errors=est-truth;
 % Fallbacks contribute to unconditional moments but do not issue confidence regions.
 Ctrial=repmat(Cfinite,1,1,N);Ctrial(:,:,~guard)=NaN;
 CknownTrial=repmat(CfiniteKnown,1,1,N);CknownTrial(:,:,~guard)=NaN;
 allSummary=jog.Core.summarize(errors,Ctrial,estimateValid,cfg.nominal);
 successSummary=jog.Core.summarize(errors,Ctrial,guard,cfg.nominal);
 knownSummary=jog.Core.summarize(known-p.gamma_z,CknownTrial,true(1,N),cfg.nominal);
 theta=2*pi*(0:n-1)/n;rho=p.horizontal_radius*[cos(theta);sin(theta)];
 out.conditions{ci}=struct('spec',c,'truth',truth,'lambda',lambda,'M',M,'Sigma_common',Sigma,...
  'H_limit',H,'floor_covariance',floorC,'floor_known_f',floorKnown,'first_order_finite_covariance',Cfinite,...
  'first_order_finite_covariance_known_f',CfiniteKnown,...
  'horizontal_coordinates_per_plane',rho,'R_n',Rn,'seed',seeds,'lambda_hat',lh,'mean_depth_observed',xd,...
  'regional_effect',b,'global_effect',globalb,'lambda_error',epsLambda,'mean_local_depth_error',epsDepth,...
  'estimate',est,'known_f_estimate',known,'errors',errors,'guard_accepted',guard,...
  'guard_min_information',information,'status',{reasons},'guard_rate',1-mean(guard),...
  'summary_all_including_fallback',allSummary,'summary_accepted',successSummary,'summary_known_f',knownSummary,...
  'depth_cv',std(c.depths,1)/mean(c.depths),'variance_inflation_free_f',floorC(1,1)/floorKnown);
end
out.notes=['Independent map common effects are redrawn each trial. The generator samples exact Gaussian sufficient statistics. ',...
 'Guard fallback trials are retained in unconditional moments. Finite covariance is first-order, the horizontal floor is a limiting result.'];
end
function s=spec(sweep,n,z,sb,sg,x)
s=struct('sweep',sweep,'n',n,'depths',z,'region_std',sb,'global_std',sg,'x',x);
end
