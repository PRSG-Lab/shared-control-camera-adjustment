classdef Additional
methods(Static)
function s=summarize(chunks,d,cfg)
 E=[];CN=[];CC=[];valid=[];ids=[];
 for i=1:numel(chunks),b=chunks{i};E=cat(2,E,b.errors);CN=cat(3,CN,b.covariance_native);CC=cat(3,CC,b.covariance_common);valid=[valid b.valid];ids=[ids b.trial_id];end
 assert(isequal(sort(ids),1:d.spec.N)&&numel(unique(ids))==d.spec.N,'Incomplete/duplicate trials');
 s=struct('spec',d.spec,'methods',{d.methods},'method',{{}},'rows',struct([]),'similarity',d.similarity,'trial_ids',ids);
 for m=1:numel(d.methods)
  a=struct();
  for b={'position','full'}
   key=b{1};if strcmp(key,'position'),ix=1:3;else,ix=1:10;end
   q=jog.Core.summarize(E(ix,:,m),CC(ix,ix,:,m),valid(m,:),cfg.nominal);
   native=jog.Core.summarize(-E(ix,:,m),CN(ix,ix,:,m),valid(m,:),cfg.nominal);
   q.nees=native.nees;q.coverage_conditional=native.coverage_conditional;q.coverage_operational=native.coverage_operational;q.coverage_wilson=native.coverage_wilson;
   a.(key)=q;
  end
  s.method{m}=a;z=find(abs(cfg.nominal-.95)<1e-9,1);
  C=d.similarity.shared_covariance;row=struct('rotation_deg',d.spec.x,'points',d.spec.n,'method',d.methods{m},'n_total',numel(ids),'n_valid',nnz(valid(m,:)),...
   'position_scatter',sqrt(trace(a.position.covariance)),'predicted_position_scatter',sqrt(trace(a.position.mean_predicted_covariance)),...
   'shared_only_position_scatter',sqrt(trace(C(1:3,1:3))),'full_coverage',a.full.coverage_conditional(z),'full_operational',a.full.coverage_operational(z),...
   'full_low',a.full.coverage_wilson(z,1),'full_high',a.full.coverage_wilson(z,2),'position_coverage',a.position.coverage_conditional(z));
  s.rows=prrev.IO.append(s.rows,row);
 end
 s.paired_estimator_difference=struct();i=find(strcmp(d.methods,'GH_LOCAL'),1);j=find(strcmp(d.methods,'GH_FULL'),1);
 if ~isempty(i)&&~isempty(j)
  ok=valid(i,:)&valid(j,:);dif=E(:,ok,i)-E(:,ok,j);s.paired_estimator_difference=struct('n_pair',nnz(ok),'difference_common_truth_chart',dif,...
   'rms_by_parameter',sqrt(mean(dif.^2,2)),'scaled_rms',sqrt(mean(sum((dif./cfg.solver.parameter_scale).^2,1))),...
   'note','Measured difference in common truth chart; equality is NOT imposed.');
 end
end
end
end
