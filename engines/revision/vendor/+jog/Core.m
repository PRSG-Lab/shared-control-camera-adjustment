classdef Core
methods(Static)
 function s=seed(cfg,suite,condition,trial)
  s=cfg.master_seed+suite*10000000+condition*10000+trial;
  assert(s<2^32 && trial<10000,'Seed range exceeded.');
 end
 function [Ni,H,rankA,condition]=normal(A,tol)
  if nargin<2,tol=1e-10;end
  scale=sqrt(sum(A.^2,1));
  if any(scale==0),error('jog:rank_deficient','Zero design column.');end
  An=A./scale; sv=svd(An,'econ'); rankA=sum(sv>tol*sv(1));
  condition=sv(1)/sv(end);
  if rankA<size(A,2),error('jog:rank_deficient','Scaled design rank deficient.');end
  Nn=An'*An; R=chol((Nn+Nn')/2);
  Ci=R\(R'\eye(size(Nn))); D=diag(1./scale);
  Ni=D*Ci*D; Ni=(Ni+Ni')/2; H=An*Ci*An'; H=(H+H')/2;
 end
 function d=linear(A,U,Qb)
  [Ni,H,ra,ca]=jog.Core.normal(A);
  T=Ni*A'*U; V=U-A*T; J=V'*V;
  if isempty(U)
   Pb=zeros(0); K=zeros(0); Omega=eye(size(A,1));
  else
   qi=Qb\eye(size(Qb)); Pb=(qi+J)\eye(size(Qb)); Pb=(Pb+Pb')/2;
   C=chol(Qb,'lower'); K=C'*J*C; Omega=eye(size(A,1))+U*Qb*U';
  end
  W=Ni*A'-T*Pb*V'; Sigma=Ni+T*Pb*T'; Sigma=(Sigma+Sigma')/2;
  Lo=chol((Omega+Omega')/2,'lower'); Ao=Lo\A;
  [direct,~,~,~]=jog.Core.normal(Ao); Wdirect=direct*Ao'/Lo;
  d=struct('A',A,'U',U,'Qb',Qb,'N_local',A'*A,'N_full',Ao'*Ao,...
   'N_local_inverse',Ni,'H',H,'T',T,'V',V,'J',J,'Q_b_given_r',Pb,...
   'K',K,'learning_spectrum',sort(max(0,eig((K+K')/2)),'descend'),...
   'Sigma',Sigma,'Sigma_direct',direct,'W',W,'W_direct',Wdirect,...
   'Omega',Omega,'rank_A',ra,'condition_A_scaled',ca);
 end
 function [v,spectrum]=inflation(d,L)
  c0=L*d.N_local_inverse*L'; dc=L*d.T*d.Q_b_given_r*d.T'*L';
  C=chol((c0+c0')/2,'lower'); M=C\dc/C';
  spectrum=1+sort(max(0,eig((M+M')/2)),'descend');v=max(spectrum);
 end
 function e=relative(A,B)
  e=norm(A-B,'fro')/max([1,norm(A,'fro'),norm(B,'fro')]);
 end
 function x=chi2(p,df)
  x=2*gammaincinv(p,df/2);
 end
 function ci=wilson(k,n)
  if n==0,ci=[NaN NaN];return;end
  z=1.95996398454005; ph=k/n; den=1+z*z/n;
  mid=(ph+z*z/(2*n))/den;
  half=z*sqrt(ph*(1-ph)/n+z*z/(4*n*n))/den; ci=[mid-half mid+half];
 end
 function s=summarize(errors,covariances,valid,nominal)
  % Columns are independent map realizations. Failures remain in total N.
  [p,N]=size(errors); ix=find(valid & all(isfinite(errors),1)); nv=numel(ix);
  s=struct('n_total',N,'n_valid',nv,'failure_rate',1-nv/N,...
   'bias',nan(p,1),'covariance',nan(p),'std',nan(p,1),'std_ci',nan(p,2),...
   'rmse',NaN,'mean_predicted_covariance',nan(p),'predicted_std',nan(p,1),...
   'nominal',nominal,'coverage_conditional',nan(size(nominal)),...
   'coverage_operational',zeros(size(nominal)),'coverage_wilson',nan(numel(nominal),2),...
   'nees',nan(1,N),'n_covariance_valid',0);
  if nv==0,return;end
  X=errors(:,ix); s.bias=mean(X,2); s.rmse=sqrt(mean(sum(X.^2,1)));
  if nv>=2
   xc=X-s.bias; s.covariance=xc*xc'/(nv-1); s.std=sqrt(max(0,diag(s.covariance)));
   mu4=mean(xc.^4,2); sevar=sqrt(max(0,(mu4-((nv-3)/(nv-1))*s.std.^4)/nv));
   s.std_ci=sqrt(max(0,[s.std.^2-1.96*sevar,s.std.^2+1.96*sevar]));
  end
  Cs=zeros(p); nc=0;
  for k=ix
   if size(covariances,3)==1,C=covariances;else,C=covariances(:,:,k);end
   if any(~isfinite(C(:))),continue;end
   [R,flag]=chol((C+C')/2);if flag~=0,continue;end
   s.nees(k)=sum((R'\errors(:,k)).^2); Cs=Cs+C;nc=nc+1;
  end
  s.n_covariance_valid=nc;
  if nc>0
   s.mean_predicted_covariance=Cs/nc;s.predicted_std=sqrt(max(0,diag(Cs/nc)));
   for a=1:numel(nominal)
    hits=sum(s.nees<=jog.Core.chi2(nominal(a),p));
    s.coverage_conditional(a)=hits/nc;s.coverage_operational(a)=hits/N;
    s.coverage_wilson(a,:)=jog.Core.wilson(hits,nc);
   end
  end
 end
 function x=quantile(v,p)
  v=sort(v(isfinite(v))); if isempty(v),x=NaN;return;end
  q=1+(numel(v)-1)*p;lo=floor(q);hi=ceil(q);x=v(lo)+(q-lo)*(v(hi)-v(lo));
 end
end
end
