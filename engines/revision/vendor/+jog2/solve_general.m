function result=solve_general(y,F,pool,cfg)
%SOLVE_CAMERA Local constrained adjustment in latent errors e=F*v.
% All methods share exactly the same observed-data initializer pool.
% Minimizes .5*||v||^2 subject to psi(y-F*v,c)=0. Redundant full-covariance
% factors are valid; their minimum-norm latent representation is selected.
t=tic; candidates=cell(size(pool));best=Inf;selected=0;
for j=1:numel(pool)
 candidates{j}=one(y,F,pool{j},cfg);
 if candidates{j}.success && candidates{j}.cost<best,best=candidates{j}.cost;selected=j;end
end
if selected==0
 result=blank(y,F);result.status='no_valid_initializer';
 if ~isempty(pool)
  result.status='nonconverged_all_candidates';
  scores=cellfun(@(x)x.final_merit,candidates);[~,j]=min(scores);
  result=candidates{j};result.success=false;result.status=['all_candidates_failed:' result.status];
 end
else,result=candidates{selected};end
result.selected_candidate=selected;result.candidate_count=numel(pool);
summaries=cell(size(candidates));
for j=1:numel(candidates)
 cc=candidates{j};summaries{j}=struct('camera',cc.camera,'success',cc.success,'status',cc.status,...
 'cost',cc.cost,'iterations',cc.iterations,'constraint_inf',cc.constraint_inf,'history',cc.history,'physical_valid',cc.physical_valid,...
 'active_parameter_bound',cc.active_parameter_bound);
end
result.candidates=summaries;result.elapsed_seconds=toc(t);
end

function r=one(y,F,c,cfg)
opt=cfg.solver;free=1:10;
if isfield(opt,'free_columns'),free=opt.free_columns;end
if isfield(opt,'focal_direct')&&opt.focal_direct,opt.parameter_scale(7)=c.scale*exp(c.phi);end
v=zeros(size(F,2),1);rho=1;history=nan(opt.max_iterations,7);
r=blank(y,F);r.camera=c;Y=y(:);status='nonconverged';it=0;
for it=1:opt.max_iterations
 mu=reshape(Y-F*v,5,[]);[psi,A,B,ok,reason]=jog.Camera.evaluate(mu,c);
 if ~ok,status=reason;break;end
 A=chartA(A,c,opt);BF=B*F;S=BF*BF';[Cs,flag]=chol((S+S')/2,'lower');
 if flag,status='singular_condition_covariance';break;end
 w=psi+BF*v;Aw=Cs\A;ww=Cs\w;
 try,[Ni,~,rankA,condA]=jog.Core.normal(Aw(:,free),opt.rank_tolerance);
 catch,status='rank_deficient';break;end
 delta=zeros(10,1);delta(free)=Ni*Aw(:,free)'*ww;lambda=Cs'\(Cs\(w-A*delta));vnew=BF'*lambda;dv=vnew-v;
 scaled=max(abs(delta)./opt.parameter_scale);closure=norm(psi,inf);
 if scaled<opt.step_tolerance && norm(dv)/max(1,norm(v))<opt.step_tolerance && closure<opt.constraint_tolerance
  status='success';history(it,:)=[.5*(v'*v),closure,scaled,0,condA,norm(dv),rho];break;
 end
 rho=max(rho,1.5*norm(lambda,inf)+1);merit=.5*(v'*v)+rho*norm(psi,1);
 slope=v'*dv-rho*norm(psi,1);accepted=false;step=1;
 for ls=1:opt.max_linesearch
  trial=chartStep(c,step*delta,opt);vt=v+step*dv;
  if ~bounds(trial,opt),step=step/2;continue;end
  [pt,~,~,good]=jog.Camera.evaluate(reshape(Y-F*vt,5,[]),trial);
  if good
   mt=.5*(vt'*vt)+rho*norm(pt,1);
   if mt<=merit+1e-4*step*min(slope,-eps*max(1,merit))
    accepted=true;break;
   end
  end
  step=step/2;
 end
 history(it,:)=[.5*(v'*v),closure,scaled,step,condA,norm(dv),rho];
 if ~accepted
  % Accept stationarity at a stricter feasibility threshold only; no silent success.
  if closure<opt.constraint_tolerance && scaled<10*opt.step_tolerance && norm(dv)/max(1,norm(v))<10*opt.step_tolerance
   status='success';
  else,status='line_search_failed';end
  break;
 end
 c=trial;v=vt;
end
r.camera=c;r.latent_error=v;r.adjusted_observations=reshape(Y-F*v,5,[]);
r.observation_correction=reshape(F*v,5,[]);r.cost=.5*v'*v;r.status=status;
r.iterations=it;r.history=history(1:it,:);r.history_columns={'cost','closure_inf','scaled_step','line_step','scaled_condition','latent_step','merit_penalty'};
[psi,A,B,ok,~]=jog.Camera.evaluate(r.adjusted_observations,c);
r.constraint_inf=norm(psi,inf);r.final_merit=r.cost+rho*norm(psi,1);
r.success=strcmp(status,'success') && ok;r.physical_valid=ok;
r.active_parameter_bound=nearBounds(c,opt);
if r.success
 A=chartA(A,c,opt);S=B*(F*F')*B';[Cs,flag]=chol((S+S')/2,'lower');
 if ~flag
  try
   [Cf,~,ra,cond]=jog.Core.normal(Cs\A(:,free),opt.rank_tolerance);C=zeros(10);C(free,free)=Cf;
   T=eye(10);if isfield(opt,'focal_direct')&&opt.focal_direct,T(7,7)=1/(c.scale*exp(c.phi));end
   r.covariance=T*C*T';r.rank=ra;r.condition_scaled=cond;
   r.sensitivity=T*C*(Cs\A)'/Cs*B;
   lambda=S\(B*F*v);r.stationarity_norm=norm(A'*lambda,inf);
  catch,r.success=false;r.status='covariance_unavailable';end
 else,r.success=false;r.status='singular_condition_covariance';end
end
if r.active_parameter_bound,r.success=false;r.status='active_parameter_bound';end
uv=jog.Camera.project(y(3:5,:),c);r.raw_reprojection=y(1:2,:)-uv;
r.raw_reprojection_coordinate_rmse=sqrt(mean(r.raw_reprojection(:).^2));
if ~cfg.save_candidate_history,r.history=[];end
end
function r=blank(y,F)
r=struct('success',false,'status','not_run','camera',[],...
 'covariance',nan(10),'sensitivity',[],'rank',NaN,'condition_scaled',NaN,...
 'latent_error',nan(size(F,2),1),'adjusted_observations',nan(size(y)),...
 'observation_correction',nan(size(y)),'cost',Inf,'final_merit',Inf,...
 'iterations',0,'history',[],'constraint_inf',Inf,'physical_valid',false,...
 'active_parameter_bound',false,'stationarity_norm',NaN,...
 'raw_reprojection',nan(2,size(y,2)),'raw_reprojection_coordinate_rmse',NaN);
end
function yes=bounds(c,opt)
f=c.scale*exp(c.phi);yes=isfinite(f)&&f>opt.focal_range(1)&&f<opt.focal_range(2)...
 &&c.kappa>opt.kappa_range(1)&&c.kappa<opt.kappa_range(2)&&all(abs(c.pp)<opt.principal_point_absmax);
end
function yes=nearBounds(c,opt)
f=c.scale*exp(c.phi);tol=1e-6;
yes=min(abs(f-opt.focal_range))<tol || min(abs(c.kappa-opt.kappa_range))<tol || any(abs(abs(c.pp)-opt.principal_point_absmax)<tol);
end

function A=chartA(A,c,opt)
if isfield(opt,'focal_direct')&&opt.focal_direct,A(:,7)=A(:,7)/(c.scale*exp(c.phi));end
end
function c=chartStep(c,delta,opt)
if isfield(opt,'focal_direct')&&opt.focal_direct
 f=c.scale*exp(c.phi);fp=f+delta(7);
 if fp<=0,c.phi=NaN;return;end
 delta(7)=log(fp/f);
end
c=jog.Camera.step(c,delta);
end
