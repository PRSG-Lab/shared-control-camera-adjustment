classdef Camera
methods(Static)
 function S=skew(x)
  S=[0 -x(3) x(2);x(3) 0 -x(1);-x(2) x(1) 0];
 end
 function R=exp(v)
  t=norm(v);K=jog.Camera.skew(v);
  if t<1e-8,R=eye(3)+K+.5*K*K;else,R=eye(3)+sin(t)/t*K+(1-cos(t))/t^2*K*K;end
 end
 function v=log(R)
  c=max(-1,min(1,(trace(R)-1)/2));t=acos(c);
  a=[R(3,2)-R(2,3);R(1,3)-R(3,1);R(2,1)-R(1,2)];
  if t<1e-7,v=.5*a;
  elseif pi-t<1e-5
   [V,D]=eig((R+R')/2);[~,i]=max(diag(D));v=t*V(:,i);if dot(v,a)<0,v=-v;end
  else,v=t/(2*sin(t))*a;end
 end
 function J=leftInverse(v)
  t=norm(v);K=jog.Camera.skew(v);
  if t<1e-5,J=eye(3)-.5*K+K*K/12;
  else,J=eye(3)-.5*K+(1/t^2-(1+cos(t))/(2*t*sin(t)))*K*K;end
 end
 function c=truth(cfg)
  x=cfg.camera;c=struct('gamma',x.gamma,'R',jog.Camera.exp(x.rotvec),...
   'phi',log(x.f/x.scale),'kappa',x.kappa,'pp',x.pp,'scale',x.scale);
 end
 function c=step(c,delta)
  c.gamma=c.gamma+delta(1:3);c.R=jog.Camera.exp(delta(4:6))*c.R;
  c.phi=c.phi+delta(7);c.kappa=c.kappa+delta(8);c.pp=c.pp+delta(9:10);
 end
 function [psi,A,B,physical,reason]=evaluate(y,c)
  n=size(y,2);psi=zeros(2*n,1);A=zeros(2*n,10);B=zeros(2*n,5*n);
  physical=true;reason='';ff=exp(c.phi);
  for i=1:n
   d=(y(1:2,i)-c.pp)/c.scale;rr=d'*d;h=1+c.kappa*rr;
   t=c.R*(y(3:5,i)-c.gamma);ii=2*i-1:2*i;jj=5*i-4:5*i;
   if t(3)<=1e-6,physical=false;reason='negative_depth';return;end
   if h<=1e-5 || 1-c.kappa*rr<=1e-5,physical=false;reason='distortion_not_invertible';return;end
   g=t(1:2)/t(3);E=eye(2)/h-2*c.kappa/h^2*(d*d');
   P=[1 0 -g(1);0 1 -g(2)]/t(3);
   psi(ii)=d/h-ff*g;
   A(ii,:)=[-ff*P*c.R,-ff*P*jog.Camera.skew(t),ff*g,rr*d/h^2,E/c.scale];
   B(ii,jj)=[E/c.scale,-ff*P*c.R];
  end
 end
 function uv=project(x,c)
  t=c.R*(x-c.gamma);a=exp(c.phi)*t(1:2,:)./t(3,:);
  disc=1-4*c.kappa*sum(a.^2,1);uv=nan(size(a));good=t(3,:)>0 & disc>0;
  lam=2./(1+sqrt(disc(good)));uv(:,good)=c.pp+c.scale*a(:,good).*lam;
 end
 function geom=geometry(cfg,n,spread,seed)
  rng(seed,'twister');c=jog.Camera.truth(cfg);x=cfg.camera;
  patch=mod(0:n-1,4)+1;signs=[-1 1 -1 1;-1 -1 1 1];
  uv=zeros(2,n);
  for i=1:n
   uv(:,i)=signs(:,patch(i)).*(.12+.88*rand(2,1)).*[x.width;x.height]*x.occupancy/2;
  end
  % Exactly fixed geometry within independent noise/map repeats.
  z=x.mean_depth*(1+spread*(rand(1,n)-.5));
  d=(uv-c.pp)/x.scale;a=d./(1+c.kappa*sum(d.^2,1));
  t=[a/exp(c.phi).*z;z];xyz=c.gamma+c.R'*t;
  geom=struct('truth_camera',c,'y_true',[uv;xyz],'patch_id',patch,...
   'point_id',1:n,'seed',seed,'spread_requested',spread,...
   'depth_actual',z,'depth_cv',std(z,1)/mean(z),...
   'image_hull_fraction',polyarea(uv(1,convhull(uv(1,:),uv(2,:))),uv(2,convhull(uv(1,:),uv(2,:))))/(x.width*x.height));
 end
 function noise=noiseModel(cfg,geom,scale,kind)
  assert(any(strcmp(kind,{'patch','global'})),'Unknown legacy noise kind');
  n=size(geom.y_true,2);x=cfg.camera;
  Ql=zeros(5*n);ratio=x.anisotropy;
  xyzvar=x.local_xyz_std^2*diag([3/(2+ratio^2),3/(2+ratio^2),3*ratio^2/(2+ratio^2)]);
  for i=1:n,jj=5*i-4:5*i;Ql(jj,jj)=blkdiag(x.local_image_std^2*eye(2),xyzvar)*scale^2;end
  if strcmp(kind,'global'),G=zeros(5*n,3);qb=x.global_std^2*scale^2*eye(3);
  else,G=zeros(5*n,12);qb=x.patch_std^2*scale^2*eye(12);end
  for i=1:n
   rr=5*i-2:5*i;if strcmp(kind,'global'),cc=1:3;else,cc=3*geom.patch_id(i)-2:3*geom.patch_id(i);end
   G(rr,cc)=eye(3);
  end
  Qfull=Ql+G*qb*G';F_local=chol(Ql,'lower');Fcommon=G*chol(qb,'lower');
  noise=struct('Q_local',Ql,'G_raw',G,'Q_b',qb,'F_local',F_local,...
   'F_common',Fcommon,'Q_full',Qfull,'kind',kind,'noise_scale',scale);
 end
 function F=factor(noise,method)
  n=size(noise.Q_local,1)/5;
  switch method
   case 'GH_FULL',F=[noise.F_local,noise.F_common];
   case 'GH_LOCAL',F=noise.F_local;
   case 'GH_MARGDIAG'
    F=zeros(5*n);for i=1:n,j=5*i-4:5*i;F(j,j)=chol(noise.Q_full(j,j),'lower');end
   case 'FIXED3D_WLS'
    F=zeros(5*n,2*n);for i=1:n,j=5*i-4:5*i-3;F(j,2*i-1:2*i)=chol(noise.Q_local(j,j),'lower');end
   otherwise,error('Unknown method');
  end
 end
 function pool=initialize(y,cfg)
  % Uses observed points only; no pose/IOP truth is passed to this routine.
  pool={};sc=cfg.camera.scale;n=size(y,2);x=y(3:5,:);
  centre=mean(x,2);sx=sqrt(mean(sum((x-centre).^2,1))/3);
  if sx<=eps,return;end
  xn=(x-centre)/sx;X=[xn;ones(1,n)];Tw=[eye(3)/sx,-centre/sx;0 0 0 1];
  for kap=cfg.nonlinear.kappa_initial
   dd=y(1:2,:)/sc;uu=dd./(1+kap*sum(dd.^2,1));
   D=zeros(2*n,12);
   for i=1:n
    D(2*i-1,:)=[X(:,i)' zeros(1,4) -uu(1,i)*X(:,i)'];
    D(2*i,:)=[zeros(1,4) X(:,i)' -uu(2,i)*X(:,i)'];
   end
   [~,S,V]=svd(D,0);if S(end-1,end-1)<1e-10*S(1,1),continue;end
   P=reshape(V(:,end),4,3)'*Tw;M=P(:,1:3);
   if rcond(M)<1e-12,continue;end
   if det(M)<0,P=-P;M=-M;end
   [Q,R]=qr(flipud(M)');K=fliplr(flipud(R'));Rc=flipud(Q');
   sg=sign(diag(K));sg(sg==0)=1;Ds=diag(sg);K=K*Ds;Rc=Ds*Rc;
   K=K/K(3,3);f=sc*mean([K(1,1),K(2,2)]);
   if f<=cfg.solver.focal_range(1)||f>=cfg.solver.focal_range(2)||det(Rc)<0,continue;end
   c=struct('gamma',-M\P(:,4),'R',Rc,'phi',log(f/sc),'kappa',kap,'pp',sc*K(1:2,3),'scale',sc);
   if any(abs(c.pp)>cfg.solver.principal_point_absmax),continue;end
   [~,~,~,ok]=jog.Camera.evaluate(y,c);if ok,pool{end+1}=c;end %#ok<AGROW>
  end
 end
 function e=error(c,truth)
  e=[c.gamma-truth.gamma;jog.Camera.log(c.R*truth.R');c.phi-truth.phi;c.kappa-truth.kappa;c.pp-truth.pp];
 end
end
end
