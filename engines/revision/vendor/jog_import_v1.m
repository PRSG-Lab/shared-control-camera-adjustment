function result=jog_import_v1(file,destination)
%JOG_IMPORT_V1 Convert complete v1 MAT condition-by-condition; no giant load.
if nargin<2,destination=fullfile(pwd,'imported_v1');end
cfg=jog2.H5Legacy.read(file,'/output/config');meta=jog2.H5Legacy.read(file,'/output/meta');
assert(strcmp(jog2.H5Legacy.read(file,'/output/schema_version'),'jog-output-1.0'));
v2=jog_config_v2(cfg.profile);fn=fieldnames(cfg);
for k=1:numel(fn),if isfield(v2,fn{k})&&~strcmp(fn{k},'schema_version'),v2.(fn{k})=cfg.(fn{k});end,end
v2.enabled=unique([cfg.enabled {'J15'}],'stable');v2.fig_dpi=600;
o=jog2.Store.create(v2,destination);o.meta.legacy_source=meta;o.meta.legacy_file_sha256=jog2.Util.filehash(file);
o.meta.legacy_source_path=file;o.meta.legacy_import='HDF5 bounded subtree -> numeric batches';
info=h5info(file,'/output/experiments');suites=cellfun(@(x)x(find(x=='/',1,'last')+1:end),{info.Groups.Name},'UniformOutput',false);
for si=1:numel(suites)
 id=suites{si};fprintf('Import %s\n',id);
 if ~strcmp(id,'J09')
  x=jog2.H5Legacy.read(file,['/output/experiments/' id]);
  [e,~]=jog2.Store.write(destination,[o.meta.run_id '_' id],x);o.legacy.(id)=e;
 else
  path='/output/experiments/J09/conditions';ncond=jog2.H5Legacy.count(file,path);
  for ci=1:ncond
   tmp=jog2.H5Legacy.read(file,path,ci);old=tmp{1};
   cases=jog2.Plan.make('J09',v2);sp=cases{ci};sp.N=numel(old.trial_id);sp.condition_id=ci;
   d=jog2.Plan.prepare(sp,v2);d.geometry=old.geometry;d.noise_model=old.noise_model;
   d.noise_model.L_b=jog2.Util.psdfactor(old.noise_model.Q_b);
   d.noise_model.components={struct('name',old.noise_model.kind,'columns',1:size(old.noise_model.Q_b,1))};
   d.noise_model.spec=sp.truth_noise;
   d.covariance_factors=old.covariance_factors;d.oracle_reference=old.oracle_reference;
   [~,A,B]=jog.Camera.evaluate(old.geometry.y_true,old.geometry.truth_camera);
   for m=1:numel(d.oracle_reference),d.oracle_reference{m}.A=A;d.oracle_reference{m}.B=B;end
   d.decomposition=jog2.Noise.decompose(old.geometry,d.noise_model,v2);
   prefix=sprintf('%s_J09c%03d',o.meta.run_id,ci);[e,~]=jog2.Store.write(destination,[prefix '_design'],d);
   c=struct('suite','J09','spec',sp,'prefix',prefix,'design',e,'batches',{{}},...
    'completed_trial_ids',old.trial_id,'run_id',o.meta.run_id);
   for k=1:v2.batch_size:sp.N
    ix=k:min(k+v2.batch_size-1,sp.N);bb=jog2.Import.batch(old,ix,d,v2);
    [e,~]=jog2.Store.write(destination,sprintf('%s_b%04d',prefix,numel(c.batches)+1),bb,'batch');
    e.trial_ids=ix;c.batches{end+1}=e;
   end
   o.conditions{end+1}=c;jog2.Store.checkpoint(o,destination);
  end
 end
 o.progress.completed_suites{end+1}=id;jog2.Store.checkpoint(o,destination);
end
outputFile=jog2.Store.finalize(destination,{});
result=struct('output_file',outputFile,'source_hash',o.meta.legacy_file_sha256,'status','imported');
end
