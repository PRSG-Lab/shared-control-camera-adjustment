function out=linear_suite(id,cfg)
%LINEAR_SUITE Fixed-design experiments J00--J06 (J03 is invariance).
out=struct('id',id,'layer','L1 fixed-design Gaussian','conditions',{{}},'notes','');
switch id
 case 'J00'
  rng(jog.Core.seed(cfg,0,0,0),'twister');C=cfg.identity_cases;
  names={'GLS estimate','GLS covariance','Mixed inverse','Orthogonality','Kernel'};
  err=zeros(C,numel(names));cond=zeros(C,1);designs=cell(C,1);
  for c=1:C
   [O,~]=qr(randn(24));A=O(:,1:4)*diag(.5+2*rand(4,1));T=randn(4,5);
   V=O(:,5:9)*randn(5);V(:,end)=0;U=A*T+V;Z=randn(5);Q=Z*Z'/5+eye(5);
   d=jog.Core.linear(A,U,Q);mix=[A'*A A'*U;U'*A U'*U+(Q\eye(5))];
   expected=[d.Sigma -d.T*d.Q_b_given_r;-d.Q_b_given_r*d.T' d.Q_b_given_r];
   h=[zeros(4,1);1];
   err(c,:)=[jog.Core.relative(d.W,d.W_direct),jog.Core.relative(d.Sigma,d.Sigma_direct),...
    jog.Core.relative(mix\eye(9),expected),norm(A'*d.V,'fro'),norm([A U]*[-d.T*h;h])];
   cond(c)=d.condition_A_scaled;designs{c}=d;
  end
  assert(max(err(:))<1e-8,'J00 algebra verification failed.');
  out.errors=err;out.error_names=names;out.condition=cond;out.designs=designs;
  out.notes='Deterministic matrix identities. Not a camera accuracy experiment.';
 case 'J01'
  g=jog.Camera.geometry(cfg,40,.15,jog.Core.seed(cfg,1,0,0));
  no=jog.Camera.noiseModel(cfg,g,1,'patch');[~,A,B]=jog.Camera.evaluate(g.y_true,g.truth_camera);
  Sl=B*no.Q_local*B';Cl=chol(Sl,'lower');U=Cl\(B*no.G_raw);
  cols={1:6,1:7,1:8,1:10};names={'EOP (6)','+ focal (7)','+ distortion (8)','+ principal point (10)'};
  old=[];
  for c=1:4
   d=jog.Core.linear(Cl\A(:,cols{c}),U,no.Q_b);L=[eye(3),zeros(3,numel(cols{c})-3)];
   [inflation,spectrum]=jog.Core.inflation(d,L);
   nullTolerance=1e-9*max(1,norm(d.V,2));Z=null(d.V,nullTolerance);
   defect=norm(L*d.T*Z,'fro');
   rec=struct('name',names{c},'parameter_columns',cols{c},'design',d,'L_target',L,...
    'position_variance_inflation',inflation,'position_inflation_spectrum',spectrum,...
    'J_drop_min_eigenvalue',NaN,'null_V',Z,'null_V_absolute_tolerance',nullTolerance,...
    'target_estimability_defect',defect,'target_estimable_against_fixed_common_effects',...
    defect<=1e-8*max(1,norm(L*d.T,'fro')));
   if c>1
    rec.J_drop_min_eigenvalue=min(eig((old-d.J+old'-d.J')/2));
    assert(rec.J_drop_min_eigenvalue>=-1e-8*max(1,norm(old,2)),'J01 information nesting failed.');
   end
   out.conditions{c}=rec;old=d.J;
  end
  out.geometry=g;out.noise=no;
  out.notes='Same truth design, observations, loading and LOCAL whitening; only IOP columns are added.';
 case 'J02'
  count=0;
  for rho=cfg.linear.rho
   for s=cfg.linear.s
    count=count+1;A=[sqrt(s);0];U=[sqrt(s) 0;0 sqrt(s)];Q=.04*[1 rho;rho 1];
    d=jog.Core.linear(A,U,Q);rec=mc(d,cfg,2,count);
    rec.rho=rho;rec.s=s;rec.target_floor=.04*(1-rho^2);
    rec.prediction_errors=rec.b-d.Q_b_given_r*d.V'*rec.residual;
    rec.prediction_covariance=cov(rec.prediction_errors');
    out.conditions{count}=rec;
   end
  end
  out.notes='Compact sufficient contrasts of s repeated observations; one hidden and one learned mode. All common effects are redrawn per trial.';
 case 'J03'
  rng(jog.Core.seed(cfg,3,0,0),'twister');err=zeros(cfg.identity_cases,3);records=cell(cfg.identity_cases,1);
  for c=1:cfg.identity_cases
   A=randn(20,4);U=randn(20,3);Q=randn(3);Q=Q*Q'+eye(3);d=jog.Core.linear(A,U,Q);
   [Mb,~]=qr(randn(3));Mb=Mb*diag([.1 2 10]);dp=jog.Core.linear(A,U/Mb,Mb*Q*Mb');
   L=[eye(2) zeros(2)];C=[2 .3;-.2 .5];
   [~,sp0]=jog.Core.inflation(d,L);[~,sp1]=jog.Core.inflation(dp,L);[~,sp2]=jog.Core.inflation(d,C*L);
   err(c,:)=[jog.Core.relative(d.learning_spectrum,dp.learning_spectrum),...
    jog.Core.relative(sp0,sp1),jog.Core.relative(sp0,sp2)];
   records{c}=struct('original',d,'transformed',dp,'M_b',Mb,'L',L,'target_transform',C,...
    'inflation_spectra',[sp0 sp1 sp2]);
  end
  assert(max(err(:))<1e-8,'J03 invariance failed.');out.errors=err;out.records=records;
  out.notes='Coordinate-change identities. Generalized eigenvalues, not individual covariance entries, are invariant.';
 case 'J04'
  s=100;A=[sqrt(s);0;0];U=[sqrt(s);0;0];
  for c=1:numel(cfg.linear.tau)
   tau=cfg.linear.tau(c);d=jog.Core.linear(A,U,.04+tau);
   N=cfg.mc_linear;b=zeros(1,N);noise=zeros(3,N);base=zeros(1,N);added=zeros(1,N);seeds=zeros(1,N);
   for k=1:N
    seeds(k)=jog.Core.seed(cfg,4,0,k);rng(seeds(k),'twister');
    base(k)=.2*randn;added(k)=randn;noise(:,k)=randn(3,1);b(k)=base(k)+sqrt(tau)*added(k);
   end
   z=U*b+noise;estimate=d.W*z;r=(eye(3)-d.H)*z;
   rec=struct('tau',tau,'s',s,'design',d,'seed',seeds,'b',b,'base_b',base,...
    'added_standard_normal',added,'noise',noise,'observations',z,'estimate',estimate,'residual',r,...
    'summary',jog.Core.summarize(estimate,d.Sigma,true(1,N),cfg.nominal),...
    'residual_energy',sum(r.^2,1));
   out.conditions{c}=rec;
  end
  out.notes='Paired base errors across tau; adding an invisible common effect leaves residuals identical, but changes target variance.';
 case 'J05'
  count=0;qb=2;
  for rate=cfg.linear.rates
   for s=cfg.linear.s
    count=count+1;delta=s^(-rate);A=[sqrt(s);0];U=[sqrt(s);sqrt(s)*delta];
    d=jog.Core.linear(A,U,qb);rec=mc(d,cfg,5,count);
    rec.s=s;rec.rate=rate;rec.delta=delta;rec.EAR=1/(1+delta^2);
    if rate<.5,rec.limit=0;elseif rate==.5,rec.limit=1/(1/qb+1);else,rec.limit=qb;end
    out.conditions{count}=rec;
   end
  end
  out.notes='Exact compact Gaussian experiment with information growth s; EAR is geometric, not an uncertainty probability.';
 case 'J06'
  out.layer='L2 reduced pinhole, fixed Jacobian';f=cfg.plane.f;gz=cfg.plane.gamma_z;o=-10;n=30;
  spread=[.005 .01 .02 .05 .1 .2 .4 .6];theta=2*pi*(0:n-1)/n;rho=3*[cos(theta);sin(theta)];
  for c=1:numel(spread)
   z=20*(1+spread(c)*linspace(-.5,.5,n));Z=gz+z;
   a=f*rho./z.^2/cfg.plane.image_std;
   A1=a(:);A2=[a(:),reshape(a.*z,[],1)];U=reshape(a.*(Z-o),[],1);
   dk=jog.Core.linear(A1,U,.01^2);df=jog.Core.linear(A2,U,.01^2);
   w=sum(a.^2,1);Zw=sum(w.*Z)/sum(w);formula=sum(w.*(Z-Zw).^2);
   assert(abs(dk.J-formula)<1e-7*max(1,formula));assert(norm(df.V)<1e-8*norm(U));
   out.conditions{c}=struct('spread',spread(c),'depths',z,'rho',rho,'known_f',dk,'free_f',df,...
    'formula_J',formula,'loading_identity_error',norm(U-A2*[gz-o;1]),'origin_z',o);
  end
  out.notes='Directional depth scale, not rigid TLS registration. Same pointwise local image whitening in fixed/free focal comparison.';
 otherwise,error('Unsupported linear experiment %s',id);
end
end

function rec=mc(d,cfg,suite,condition)
N=cfg.mc_linear;n=size(d.A,1);r=size(d.U,2);
b=zeros(r,N);ee=zeros(n,N);seed=zeros(1,N);C=chol(d.Qb,'lower');
for k=1:N
 seed(k)=jog.Core.seed(cfg,suite,condition,k);rng(seed(k),'twister');
 b(:,k)=C*randn(r,1);ee(:,k)=randn(n,1);
end
z=d.U*b+ee;estimate=d.W*z;residual=(eye(n)-d.H)*z;
rec=struct('design',d,'seed',seed,'b',b,'noise',ee,'observations',z,...
 'truth_parameter',zeros(size(d.A,2),1),'estimate',estimate,'residual',residual,...
 'summary',jog.Core.summarize(estimate,d.Sigma,true(1,N),cfg.nominal));
end
