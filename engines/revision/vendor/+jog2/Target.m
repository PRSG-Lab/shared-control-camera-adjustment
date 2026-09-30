classdef Target
methods(Static)
function t=design(g,cfg)
 c=g.truth_camera;k=cfg.j15.grid_size;
 [u,v]=meshgrid(linspace(-cfg.camera.width,cfg.camera.width,k)*cfg.j15.halfwidth_fraction,...
  linspace(-cfg.camera.height,cfg.camera.height,k)*cfg.j15.halfwidth_fraction);
 t=struct('uv',c.pp+[u(:)';v(:)'],'normal',c.R'*[0;0;1],...
 'origin',c.gamma+cfg.j15.depth*c.R'*[0;0;1],...
 'basis',c.R'*[1 0;0 1;0 0],'grid_size',k);
 [t.plane_truth,t.checkpoints]=jog2.Target.plane(c,t);
 t.image_truth=jog.Camera.project(t.checkpoints,c);
 t.region_dimension=2;t.noise_scope='camera only; exact independent plane and checkpoints';
end
function [z,X]=plane(c,t)
 d=(t.uv-c.pp)/c.scale;h=1+c.kappa*sum(d.^2,1);
 rays=c.R'*[d./h;exp(c.phi)*ones(1,size(d,2))];
 den=t.normal'*rays;lambda=(t.normal'*(t.origin-c.gamma))./den;
 X=c.gamma+rays.*lambda;bad=abs(den)<1e-12|lambda<=0|h<=1e-5|1-c.kappa*sum(d.^2,1)<=1e-5;
 X(:,bad)=NaN;z=t.basis'*(X-t.origin);
end
function [y,J]=values(c,t,kind,stepMultiplier)
 if nargin<4,stepMultiplier=1;end
 if strcmp(kind,'plane'),y=jog2.Target.plane(c,t);else,y=jog.Camera.project(t.checkpoints,c);end
 J=zeros(2,size(y,2),10);steps=[1e-4 1e-4 1e-4 1e-6 1e-6 1e-6 1e-6 1e-6 1e-3 1e-3];
 for q=1:10
  e=zeros(10,1);e(q)=steps(q)*stepMultiplier;cp=jog.Camera.step(c,e);cm=jog.Camera.step(c,-e);
  if strcmp(kind,'plane'),yp=jog2.Target.plane(cp,t);ym=jog2.Target.plane(cm,t);
  else,yp=jog.Camera.project(t.checkpoints,cp);ym=jog.Camera.project(t.checkpoints,cm);end
  J(:,:,q)=(yp-ym)/(2*steps(q)*stepMultiplier);
 end
end
function z=batch(b,d,cfg)
 t=jog2.Target.design(d.geometry,cfg);T=size(t.uv,2);N=numel(b.trial_id);M=numel(d.methods);
 z=struct('trial_id',b.trial_id,'plane_error',nan(2,T,N,M),'image_error',nan(2,T,N,M),...
 'plane_covariance',nan(2,2,T,N,M),'image_covariance',nan(2,2,T,N,M),...
 'plane_nees',nan(T,N,M),'image_nees',nan(T,N,M));
 for m=1:M
  for k=1:N
   if ~b.valid(m,k),continue;end
   c=jog2.Util.vecCam(b.cameras(:,m,k),d.geometry.truth_camera.scale);
   for kind={'plane','image'}
    name=kind{1};[val,J]=jog2.Target.values(c,t,name);err=val-t.([name '_truth']);
    z.([name '_error'])(:,:,k,m)=err;
    for q=1:T
     L=reshape(J(:,q,:),2,10);C=L*b.covariance_native(:,:,k,m)*L';C=(C+C')/2;
     z.([name '_covariance'])(:,:,q,k,m)=C;
     if any(~isfinite(C(:)))||any(~isfinite(err(:,q))),continue;end
     [R,flag]=chol(C,'lower');if flag==0,z.([name '_nees'])(q,k,m)=sum((R\err(:,q)).^2);end
    end
   end
  end
 end
 z.meta=struct('target_design',t,'region_type','pointwise_chi2_2','independent_unit','camera map',...
 'derivative','central differences with left SO3 perturbation');
end
function s=summarize(chunks,d,cfg)
 s=struct('methods',{d.methods},'definition','pointwise 2D camera-only target regions','targets',[]);
 for kind={'plane','image'}
  name=kind{1};err=[];nees=[];covar=[];
  for b=1:numel(chunks)
   err=cat(3,err,chunks{b}.([name '_error']));nees=cat(2,nees,chunks{b}.([name '_nees']));
   covar=cat(4,covar,chunks{b}.([name '_covariance']));
  end
  [~,T,N,M]=size(err);a=struct('rmse',nan(T,M),'bias',nan(2,T,M),'empirical_covariance',nan(2,2,T,M),...
   'predicted_covariance',nan(2,2,T,M),'predicted_scatter',nan(T,M),...
   'coverage_wilson',nan(T,2,M),'coverage',nan(T,M),'coverage_operational',zeros(T,M),'valid_count',zeros(T,M),'ellipse_area',nan(T,M));
  for m=1:M
   for q=1:T
    e=reshape(err(:,q,:,m),2,N);v=reshape(nees(q,:,m),1,N);ok=isfinite(v);
    if ~any(ok),continue;end
    a.rmse(q,m)=sqrt(mean(sum(e(:,ok).^2,1)));a.bias(:,q,m)=mean(e(:,ok),2);
    if nnz(ok)>1,a.empirical_covariance(:,:,q,m)=cov(e(:,ok)');end
    a.valid_count(q,m)=nnz(ok);a.coverage(q,m)=mean(v(ok)<=jog.Core.chi2(.95,2));
    a.coverage_operational(q,m)=sum(v<=jog.Core.chi2(.95,2))/N;
    a.coverage_wilson(q,:,m)=jog.Core.wilson(sum(v(ok)<=jog.Core.chi2(.95,2)),nnz(ok));
    mc=mean(covar(:,:,q,ok,m),4);a.predicted_covariance(:,:,q,m)=mc;a.predicted_scatter(q,m)=sqrt(trace(mc));
    areas=[];for k=find(ok),C=covar(:,:,q,k,m);areas(end+1)=pi*jog.Core.chi2(.95,2)*sqrt(max(0,det(C)));end
    a.ellipse_area(q,m)=mean(areas);
   end
  end
  s.(name)=a;
 end
 t=chunks{1}.meta.target_design;s.targets=t;
 s.inflation=struct();
 for kind={'plane','image'}
  [~,J]=jog2.Target.values(d.geometry.truth_camera,t,kind{1});v=nan(1,size(J,2));
  for q=1:numel(v),L=reshape(J(:,q,:),2,10);v(q)=jog.Core.inflation(d.decomposition,L);end
  s.inflation.(kind{1})=v;
 end
end
end
end
