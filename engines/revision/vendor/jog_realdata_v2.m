function file=jog_realdata_v2(data,cfg,destination)
%JOG_REALDATA_V2 Optional R01 adapter: measured y + externally supplied Q.
% data.y: 5xn [u;v;X;Y;Z], centered pixels/metres.
% data.Q_local, data.G_raw, data.Q_b, data.covariance_provenance required.
% No empirical camera coverage is inferred from a single real map.
required={'y','Q_local','G_raw','Q_b','covariance_provenance'};
for k=1:numel(required),assert(isfield(data,required{k}),'Missing real-data field %s',required{k});end
assert(size(data.y,1)==5&&size(data.y,2)>=6);
no=struct('Q_local',data.Q_local,'G_raw',data.G_raw,'Q_b',data.Q_b);
no.F_local=jog2.Util.psdfactor(no.Q_local);no.F_common=no.G_raw*jog2.Util.psdfactor(no.Q_b);
no.Q_full=no.Q_local+no.F_common*no.F_common';
pool=jog.Camera.initialize(data.y,cfg);fits=cell(size(cfg.nonlinear.methods));
for m=1:numel(fits),F=jog.Camera.factor(no,cfg.nonlinear.methods{m});fits{m}=jog.solve_camera(data.y,F,pool,cfg);end
if ~exist(destination,'dir'),mkdir(destination);end
output=struct('schema_version','jog-real-2.0','config',cfg,'data',data,'noise_model',no,...
 'methods',{cfg.nonlinear.methods},'initializers',{pool},'fits',{fits},...
 'meta',struct('dataset_type','real_single_map','created_utc',jog2.Util.utc(),...
 'source_code',jog2.Util.sources(),'coverage_claim','not estimated from one map',...
 'complete',true,'covariance_source',data.covariance_provenance));
file=fullfile(destination,'output.mat');assert(~exist(file,'file'),'Destination exists');save(file,'output','-v7.3');
end
