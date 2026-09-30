function report=jog_check_output_v2(file,mode)
if nargin<2,mode='strict';end
o=jog2.Store.metadata(file);assert(strcmp(o.schema_version,'jog-output-2.1'));
assert(o.meta.complete,'Partial run is not a finished output');
assert(jog2.Archive.isArchive(file));entries=jog2.Store.entries(o);
for k=1:numel(entries),assert(jog2.Archive.ready(file,entries{k}),'Missing/incomplete payload');end
report=struct('passed',true,'conditions',numel(o.conditions),'maps',0,'fits',0,...
 'successful_fits',0,'observation_reconstruction_error',0,'max_valid_closure',0,'covariance_asymmetry',0,...
 'data_self_contained',true,'checked_utc',jog2.Util.utc(),'mode',mode);
for i=1:numel(o.conditions)
 c=o.conditions{i};d=jog2.Store.design(file,c);ids=[];
 fprintf('Integrity %s %d/%d\n',c.suite,i,numel(o.conditions));
 for j=1:numel(c.batches)
  b=jog2.Store.read(file,c.batches{j});ids=[ids b.trial_id];
  y=d.geometry.y_true+reshape(b.eta,5,d.spec.n,[]);
  er=max(abs(y(:)-b.observations(:)));report.observation_reconstruction_error=max(report.observation_reconstruction_error,er);
  assert(er<1e-10,'Observation data mismatch');
  report.maps=report.maps+numel(b.trial_id);report.fits=report.fits+numel(b.valid);
  report.successful_fits=report.successful_fits+nnz(b.valid);
  if any(b.valid(:)),report.max_valid_closure=max(report.max_valid_closure,max(b.closure(b.valid)));end
  for m=1:numel(d.methods)
   for k=find(b.valid(m,:))
    C=b.covariance_native(:,:,k,m);[~,flag]=chol((C+C')/2);assert(flag==0&&all(isfinite(C(:))),'Invalid covariance flagged valid');
    report.covariance_asymmetry=max(report.covariance_asymmetry,norm(C-C','fro')/max(1,norm(C,'fro')));
   end
  end
 end
 assert(isequal(sort(ids),1:c.spec.N)&&numel(unique(ids))==numel(ids),'Missing or duplicate trials');
end
report.map_count_definition='condition-map evaluations; paired scales/geometries are correlated across conditions';
o.validation.integrity=report;report.root_link_count=jog2.Archive.rootCount(file);o.validation.integrity=report;jog2.Store.saveMetadata(file,o);
log=fullfile(fileparts(file),'integrity.json');f=fopen(log,'w');cl=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(report,PrettyPrint=true));
fprintf('Integrity OK: %d condition-map evaluations, %d fits, %d valid\n',report.maps,report.fits,report.successful_fits);
end
