classdef Geometry
methods(Static)
function g=paired(cfg,n,spread,j,gid)
 [r,sid]=jog2.Util.stream(cfg,j,gid,0,0,0);
 uvU=rand(r,2,60);zU=rand(r,1,60);c=jog.Camera.truth(cfg);x=cfg.camera;
 patch=mod(0:59,4)+1;sg=[-1 1 -1 1;-1 -1 1 1];
 uv=sg(:,patch).*(.12+.88*uvU).*[x.width;x.height]*x.occupancy/2;
 z=x.mean_depth*(1+spread*(zU-.5));
 d=(uv-c.pp)/x.scale;a=d./(1+c.kappa*sum(d.^2,1));
 xyz=c.gamma+c.R'*[a/exp(c.phi).*z;z];
 hull=convhull(uv(1,1:n),uv(2,1:n));
 g=struct('truth_camera',c,'y_true',[uv(:,1:n);xyz(:,1:n)],...
 'patch_id',patch(1:n),'point_id',1:n,'seed',cfg.revision_seed,'substream',sid,...
 'spread_requested',spread,'depth_actual',z(1:n),'depth_cv',std(z(1:n),1)/mean(z(1:n)),...
 'image_hull_fraction',polyarea(uv(1,hull),uv(2,hull))/(x.width*x.height),...
 'master_xyz',xyz,'master_uv',uv,'master_depth_u',zU,'generator','paired_60');
end
function g=legacy(cfg,n,spread)
 seed=cfg.master_seed+200000000+n*1000+round(1000*spread);
 g=jog.Camera.geometry(cfg,n,spread,seed);g.generator='legacy_twister';
end
function [g,found]=sourceGeometry(file,n,spread)
 found=false;g=[];if isempty(file),return;end
 o=jog2.Store.metadata(file);
 if strcmp(o.schema_version,'jog-output-1.0')
  error('jog2:importFirst','Import v1 first with jog_import_v1.');
 end
 for i=1:numel(o.conditions)
  e=o.conditions{i};
  if strcmp(e.suite,'J09')&&e.spec.n==n&&abs(e.spec.depth_spread-spread)<1e-12
   d=jog2.Store.design(file,e);g=d.geometry;found=true;return;
  end
 end
end
end
end
