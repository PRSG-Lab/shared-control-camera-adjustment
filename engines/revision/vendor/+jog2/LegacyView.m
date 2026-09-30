classdef LegacyView
methods(Static)
function old=make(file,o,E)
 idx=find(cellfun(@(c)strcmp(c.suite,'J09'),o.conditions));conditions={};
 for i=idx
  c=o.conditions{i};d=jog2.Store.design(file,c);s=o.summaries{i};
  errors=[];valid=[];maxaxes=[];
  for b=1:numel(c.batches)
   raw=jog2.Store.read(file,c.batches{b});errors=cat(2,errors,raw.errors);valid=[valid raw.valid];
   axes=nan(numel(d.methods),numel(raw.trial_id));
   for m=1:numel(d.methods)
    for k=find(raw.valid(m,:))
     ev=eig(raw.covariance_native(1:3,1:3,k,m));axes(m,k)=sqrt(jog.Core.chi2(.95,3)*max(ev));
    end
   end
   maxaxes=[maxaxes axes];
  end
  ss=cell(size(s.method));
  for m=1:numel(ss)
   a=s.method{m};z=a.blocks.full;z.position=a.blocks.position;z.eop=a.blocks.eop;
   z.raw_reprojection_coordinate_rmse=a.reprojection_rmse;z.position_error_norm=sqrt(sum(errors(1:3,:,m).^2,1));
   z.median_maxaxis95=jog.Core.quantile(maxaxes(m,:),.5);ss{m}=z;
  end
  conditions{end+1}=struct('spec',c.spec,'methods',{d.methods},'summary',{ss},...
   'valid',valid,'errors',errors,'oracle_reference',{d.oracle_reference});
 end
 if ~isempty(conditions),E.J09=struct('conditions',{conditions});end
 cfg=o.config;cfg.fig_dpi=300;old=struct('config',cfg,'experiments',E);
end
end
end
