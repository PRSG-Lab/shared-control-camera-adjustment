classdef Plot
methods(Static)
function p=panel(xlabel,ylabel,scale)
 if nargin<3,scale='linear';end
 p=struct('type','line','xlabel',xlabel,'ylabel',ylabel,'scale',scale,'series',{{}},...
 'matrix',[],'xlabels',{{}},'ylabels',{{}},'reference',[],'source_ids',{{}});
end
function p=curve(p,x,y,name,lo,hi)
 if nargin<5,lo=[];hi=[];end
 p.series{end+1}=struct('x',x(:)','y',y(:)','label',name,'lower',lo(:)','upper',hi(:)');
end
function [manifest,data]=render(asset,panels,caption,o,dest)
 cfg=o.config;data=struct('asset_id',asset,'panels',{panels},'caption',caption,...
 'run_id',o.meta.run_id,'config_hash',o.meta.config_hash,'nominal',cfg.nominal,...
 'source_conditions',{cellfun(@(c)struct('run_id',c.run_id,'suite',c.suite,'spec',c.spec),o.conditions,'UniformOutput',false)},...
 'definition','empirical curves from independent maps within condition; paired conditions may share normals',...
 'profile',cfg.profile,'export_dpi',cfg.fig_dpi);
 if ~exist(dest,'dir'),mkdir(dest);end
 nc=min(2,numel(panels));nr=ceil(numel(panels)/nc);
 f=figure('Visible',cfg.figure_visible,'Color','w','Units','centimeters','Position',[2 2 17 max(7,6.2*nr)]);
 clean=onCleanup(@()close(f));tiledlayout(nr,nc,'TileSpacing','compact','Padding','compact');
 colors=[0 .447 .698;.835 .369 0;0 .62 .45;.8 .475 .655;.35 .35 .35;.9 .65 0;.1 .6 .8;.5 .3 .2];
 for i=1:numel(panels)
  a=nexttile;p=panels{i};hold(a,'on');
  if strcmp(p.type,'heat')
   imagesc(a,p.matrix);set(a,'YDir','normal');colorbar(a);
   if ~isempty(p.xlabels),xticks(a,1:numel(p.xlabels));xticklabels(a,p.xlabels);xtickangle(a,25);end
   if ~isempty(p.ylabels),yticks(a,1:numel(p.ylabels));yticklabels(a,p.ylabels);end
   xlim(a,[.5 size(p.matrix,2)+.5]);ylim(a,[.5 size(p.matrix,1)+.5]);
   if ~isempty(p.reference),clim(a,p.reference);end
  else
   for j=1:numel(p.series)
    v=p.series{j};co=colors(1+mod(j-1,size(colors,1)),:);style='-o';
    methodnames={'FIXED3D_WLS','GH_LOCAL','GH_MARGDIAG','GH_FULL'};
    for mi=1:4,if contains(v.label,methodnames{mi}),co=colors(mi,:);end,end
    if contains(lower(v.label),'predicted')||contains(lower(v.label),'floor'),style='--s';end
    if strcmp(p.type,'ellipse'),style='-';end
    if isempty(v.lower)
     plot(a,v.x,v.y,style,'Color',co,'LineWidth',1.1,'MarkerSize',3,'DisplayName',v.label);
    else
     errorbar(a,v.x,v.y,max(0,v.y-v.lower),max(0,v.upper-v.y),'o-','Color',co,...
      'LineWidth',1,'MarkerSize',3,'DisplayName',v.label);
    end
   end
   if ~isempty(p.reference),for z=p.reference,yline(a,z,'k:','HandleVisibility','off');end,end
   if strcmp(p.type,'ellipse'),axis(a,'equal');end
   if contains(p.scale,'logx'),set(a,'XScale','log');end
   if contains(p.scale,'logy'),set(a,'YScale','log');end
   if ~isempty(p.xlabels),xticks(a,1:numel(p.xlabels));xticklabels(a,p.xlabels);xtickangle(a,25);end
   if ~isempty(p.series),legend(a,'Location','best','Interpreter','none','FontSize',7);end
   grid(a,'on');
  end
  xlabel(a,p.xlabel,'Interpreter','none');ylabel(a,p.ylabel,'Interpreter','none');
  ttl=sprintf('(%c)',96+i);if isfield(p,'subtitle'),ttl=[ttl ' ' p.subtitle];end
  title(a,ttl,'FontWeight','normal','Interpreter','none');set(a,'FontName','Arial','FontSize',8,'Box','on');
 end
 png=fullfile(dest,[asset '.png']);pdf=fullfile(dest,[asset '.pdf']);
 exportgraphics(f,png,'Resolution',cfg.fig_dpi);exportgraphics(f,pdf,'ContentType','vector');
 if cfg.export_eps,exportgraphics(f,fullfile(dest,[asset '.eps']),'ContentType','vector');end
 txt=fullfile(dest,[asset '_caption.md']);h=fopen(txt,'w');fprintf(h,'# %s\n\n%s\n\nProfile: %s. Source: %s.\n',asset,caption,cfg.profile,o.meta.run_id);fclose(h);
 manifest=struct('asset_id',asset,'png',[asset '.png'],'pdf',[asset '.pdf'],...
 'caption',[asset '_caption.md'],'status','generated','data_field',matlab.lang.makeValidName(asset));
end
end
end
