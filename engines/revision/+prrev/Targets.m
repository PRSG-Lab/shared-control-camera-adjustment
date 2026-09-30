classdef Targets
methods(Static)
function ts=design(g,cfg,opt)
 c=g.truth_camera;ts={};
 for depth=opt.depths,ts{end+1}=one(depth,0,opt.halfwidth_fraction);end
 for tilt=opt.tilts_deg,ts{end+1}=one(opt.oblique_depth,tilt,opt.oblique_halfwidth_fraction);end
 function t=one(depth,tilt,hw)
  k=opt.grid_size;[u,v]=meshgrid(linspace(-cfg.camera.width,cfg.camera.width,k)*hw,linspace(-cfg.camera.height,cfg.camera.height,k)*hw);
  R=jog.Camera.exp([0;tilt*pi/180;0]);t=struct('id',sprintf('depth%g_tilt%g',depth,tilt),...
   'uv',c.pp+[u(:)';v(:)'],'normal',c.R'*R*[0;0;1],'origin',c.gamma+depth*c.R'*[0;0;1],...
   'basis',c.R'*R(:,1:2),'grid_size',k,'depth',depth,'tilt_deg',tilt,'halfwidth_fraction',hw);
  [t.plane_truth,t.checkpoints]=jog2.Target.plane(c,t);t.image_truth=jog.Camera.project(t.checkpoints,c);
  t.truth_valid=all(isfinite(t.plane_truth),1)&all(isfinite(t.image_truth),1);
  t.scope='camera-only, exact independent plane and object check points; pointwise 2D regions';
  t.is_depth_extrapolation=depth<min(g.depth_actual)||depth>max(g.depth_actual);
  t.control_depth_range=[min(g.depth_actual),max(g.depth_actual)];
 end
end
function z=batch(b,d,ts,opt)
 ix=find(ismember(d.methods,opt.methods));assert(~isempty(ix),'No requested method');N=numel(b.trial_id);
 z=struct('trial_id',b.trial_id,'methods',{d.methods(ix)},'target',{{}});
 for ti=1:numel(ts)
  t=ts{ti};T=size(t.uv,2);M=numel(ix);
  r=struct('design',t,'plane_error',nan(2,T,N,M),'image_error',nan(2,T,N,M),...
   'plane_covariance',nan(2,2,T,N,M),'image_covariance',nan(2,2,T,N,M),...
   'plane_nees',nan(T,N,M),'image_nees',nan(T,N,M),'camera_valid',b.valid(ix,:));
  for mm=1:M
   m=ix(mm);
   for k=1:N
    if ~b.valid(m,k),continue;end
    cam=jog2.Util.vecCam(b.cameras(:,m,k),d.geometry.truth_camera.scale);
    for kinds={'plane','image'}
     kind=kinds{1};[y,J]=jog2.Target.values(cam,t,kind,opt.target.derivative_step_multiplier);
     err=y-t.([kind '_truth']);r.([kind '_error'])(:,:,k,mm)=err;
     for q=1:T
      L=reshape(J(:,q,:),2,10);C=L*b.covariance_native(:,:,k,m)*L';C=(C+C')/2;
      r.([kind '_covariance'])(:,:,q,k,mm)=C;
      if ~t.truth_valid(q)||any(~isfinite(C(:)))||any(~isfinite(err(:,q))),continue;end
      [F,p]=chol(C,'lower');if p==0,r.([kind '_nees'])(q,k,mm)=sum((F\err(:,q)).^2);end
     end
    end
   end
  end
  z.target{ti}=r;
 end
end
function s=summarize(records,condition)
 ts=records{1}.target;methods=records{1}.methods;M=numel(methods);allids=cellfun(@(x)x.trial_id,records,'UniformOutput',false);ids=[allids{:}];
 assert(numel(unique(ids))==numel(ids),'Duplicate trials');N=numel(ids);
 s=struct('condition',condition,'methods',{methods},'trial_ids',ids,'n_total',N,'targets',{{}},'rows',struct([]));
 for ti=1:numel(ts)
  t=ts{ti}.design;T=size(t.uv,2);a=struct('design',t);
  for kinds={'plane','image'}
   kind=kinds{1};E=[];V=[];C=[];
   for j=1:numel(records),r=records{j}.target{ti};E=cat(3,E,r.([kind '_error']));V=cat(2,V,r.([kind '_nees']));C=cat(4,C,r.([kind '_covariance']));end
   x=struct('rmse',nan(T,M),'bias',nan(2,T,M),'empirical_covariance',nan(2,2,T,M),...
    'predicted_covariance',nan(2,2,T,M),'coverage',nan(T,M),'coverage_operational',nan(T,M),...
    'wilson',nan(T,2,M),'valid_count',zeros(T,M),'error_valid_count',zeros(T,M));
   for m=1:M
    for q=1:T
     err=reshape(E(:,q,:,m),2,N);v=reshape(V(q,:,m),1,N);ok=isfinite(v);ep=all(isfinite(err),1);
     if ~t.truth_valid(q),ok(:)=false;ep(:)=false;end
     ne=nnz(ep);nv=nnz(ok);hit=sum(v(ok)<=jog.Core.chi2(.95,2));
     x.error_valid_count(q,m)=ne;x.valid_count(q,m)=nv;if t.truth_valid(q),x.coverage_operational(q,m)=hit/N;end
     if ne>0,x.rmse(q,m)=sqrt(mean(sum(err(:,ep).^2,1)));x.bias(:,q,m)=mean(err(:,ep),2);end
     if ne>1,x.empirical_covariance(:,:,q,m)=cov(err(:,ep)');end
     if nv>0,x.coverage(q,m)=hit/nv;x.wilson(q,:,m)=jog.Core.wilson(hit,nv);x.predicted_covariance(:,:,q,m)=mean(C(:,:,q,ok,m),4);end
     row=struct('condition',condition,'target',t.id,'kind',kind,'method',methods{m},'point',q,...
      'depth_m',t.depth,'tilt_deg',t.tilt_deg,'truth_valid',t.truth_valid(q),'n_total',N,'n_error_valid',ne,'n_covariance_valid',nv,...
      'rmse',x.rmse(q,m),'coverage',x.coverage(q,m),'coverage_operational',x.coverage_operational(q,m),'wilson_low',x.wilson(q,1,m),'wilson_high',x.wilson(q,2,m));
     s.rows=prrev.IO.append(s.rows,row);
    end
   end
   a.(kind)=x;
  end
  s.targets{ti}=a;
 end
 s.note='RMSE uses finite camera-derived errors; conditional coverage uses valid propagated covariance. Operational coverage counts failed fits/targets as misses. Undefined truth targets remain NaN.';
end
end
end
