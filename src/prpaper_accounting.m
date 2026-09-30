function [by_condition,totals,invalid_by_method]=prpaper_accounting(metrics)
%PRPAPER_ACCOUNTING Count fits once, independently of parameter-block tables.
t=metrics(strcmp(metrics.Block,'position'),:);
keys=unique(t(:,{'Suite','Experiment','Condition_ID'}),'rows','stable');r={};
for i=1:height(keys)
 q=t(strcmp(t.Suite,keys.Suite{i})&t.Condition_ID==keys.Condition_ID(i),:);
 assert(numel(unique(q.N))==1,'Treatments disagree about the observation count.');
 r{end+1}=struct('Suite',keys.Suite{i},'Experiment',keys.Experiment{i},...
  'Condition',keys.Condition_ID(i),'Realisations',q.N(1),'Treatments',height(q),...
  'Fits',sum(q.N),'Valid_fits',sum(q.Valid),'Invalid_fits',sum(q.N-q.Valid)); %#ok<AGROW>
end
by_condition=struct2table([r{:}]);
totals=table(height(by_condition),sum(by_condition.Realisations),sum(by_condition.Fits),...
 sum(by_condition.Valid_fits),sum(by_condition.Invalid_fits),...
 sum(by_condition.Fits-4*by_condition.Realisations),...
 'VariableNames',{'Conditions','Condition_realisations','Fits','Valid_fits','Invalid_fits','Fits_above_four_per_realisation'});
names=unique(t.Method,'stable');n=zeros(numel(names),1);
for i=1:numel(names),q=t(strcmp(t.Method,names{i}),:);n(i)=sum(q.N-q.Valid);end
invalid_by_method=table(names,n,'VariableNames',{'Method','Invalid_fits'});
end
