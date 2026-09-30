classdef Validate
methods(Static)
function config(c)
 assert(c.batch_size>=1&&mod(c.batch_size,1)==0);
 assert(c.mc_nonlinear<10000&&c.mc_linear<10000&&c.mc_plane<10000);
 assert(c.j12.geometries<100&&c.j12.maps<10000);
 assert(all(ismember(c.j11.extensions,{'M2','M3','M5'})));
 assert(c.save_candidate_history,'Complete package requires candidate histories');
 assert(~c.parallel,'Serial reference implementation: cfg.parallel must be false');
 for k=1:numel(c.source_runs),assert(exist(c.source_runs{k},'file')==2,'Missing source run');end
end
function r=preflight(c,folder)
 count=0;fits=0;
 for k=1:numel(c.enabled)
  j=str2double(c.enabled{k}(2:end));
  if j>=9&&j<=14
   cases=jog2.Plan.make(c.enabled{k},c);
   for z=1:numel(cases),count=count+cases{z}.N;fits=fits+cases{z}.N*numel(cases{z}.variants);end
  end
 end
 % Conservative planning estimate based on prior v1 file; not a runtime promise.
 bytes=6.5*2^30/96000*fits;free=java.io.File(folder).getUsableSpace();
 r=struct('condition_map_evaluations',count,'fits',fits,'estimated_gib',bytes/2^30,...
 'free_gib',double(free)/2^30,'basis','v1 6.5GiB / 96000 fits, rough; pilot measurement required',...
 'is_precision_runtime_estimate',false);
 assert(r.free_gib>=max(c.preflight.min_free_gib,2*r.estimated_gib),'Insufficient estimated free disk for shards + final MAT');
 assert(r.estimated_gib<=c.preflight.max_estimated_gib,'Configured storage budget exceeded');
 fprintf('Preflight: %d fits, rough %.2f GiB final, %.1f GiB disk free\n',fits,r.estimated_gib,r.free_gib);
end
end
end
