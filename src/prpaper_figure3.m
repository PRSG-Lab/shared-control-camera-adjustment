function [f,p]=prpaper_figure3(DATA,opt)
%PRPAPER_FIGURE3 Current two-panel E03 figure from computed condition summaries.
% Panel (a): combined patch/global errors. Panel (b): separate patch-only case.
P=[0 114 178;213 94 0]/255;
f=figure('WindowStyle','normal','Visible',opt.visible,'Color','white',...
 'Units','centimeters','Position',[1 1 18 10.4]);
set(f,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial',...
 'DefaultAxesFontSize',9,'DefaultTextFontSize',9);
axes1=axes(f,'Position',[.17 .26 .34 .58]);hold(axes1,'on');
axes2=axes(f,'Position',[.64 .26 .34 .58]);hold(axes2,'on');
p=struct('panel_a',{{}},'panel_b',{{}},'definition',...
 'Conditional coverage and pointwise 95% Wilson intervals; same two experiments as manuscript v0.19.');
methods={'FULL_correct','omit_global','omit_patch','GH_LOCAL'};
names={'Correct full','Omit global','Omit patch','Omit both'};
blocks={'position','full'};legendNames={'Position (3D)','Full camera (10D)'};
h=gobjects(3,1);marker='os';
for j=1:2
 for k=1:4
  q=metric(DATA,2,methods{k},blocks{j});y=5-k+(.5-(j-1))*.22;
  hh=errorbar(axes1,100*q.coverage,y,100*(q.coverage-q.lower),100*(q.upper-q.coverage),...
   'horizontal','LineStyle','none','Marker',marker(j),'Color',P(j,:),...
   'MarkerSize',4,'CapSize',3,'LineWidth',1);
  if k==1,h(j)=hh;end
  q.method=methods{k};q.block=blocks{j};q.y=y;p.panel_a{end+1}=q;
 end
end
h(3)=xline(axes1,95,':','Color',[.3 .3 .3],'LineWidth',1);
set(axes1,'YTick',1:4,'YTickLabel',flip(names),'XTick',0:25:100,'Box','off',...
 'XGrid','on','YGrid','off','GridAlpha',.15,'FontSize',9);
xlim(axes1,[-2 103]);ylim(axes1,[.5 4.5]);xlabel(axes1,'Coverage (%)');
title(axes1,{'(a) Combined patch','+ global'},'FontSize',9,'FontWeight','bold');
alpha=[.25 .5 1 2 4];
for j=1:2
 vals=zeros(1,5);lo=vals;hi=vals;
 for k=1:5
  method=sprintf('FULL_alpha_%g',alpha(k));q=metric(DATA,1,method,blocks{j});
  vals(k)=q.coverage;lo(k)=q.lower;hi(k)=q.upper;
  q.multiplier=alpha(k);q.method=method;q.block=blocks{j};p.panel_b{end+1}=q;
 end
 errorbar(axes2,alpha,100*vals,100*(vals-lo),100*(hi-vals),...
  'Marker',marker(j),'Color',P(j,:),'MarkerSize',4,'CapSize',3,'LineWidth',1);
end
yline(axes2,95,':','Color',[.3 .3 .3],'LineWidth',1);
set(axes2,'XScale','log','XTick',alpha,'XTickLabel',{'0.25','.5','1','2','4'},...
 'YTick',0:25:100,'Box','off','XGrid','on','YGrid','on','GridAlpha',.15,'FontSize',9);
xlim(axes2,[.20 5]);ylim(axes2,[-2 103]);ylabel(axes2,'Coverage (%)');
xlabel(axes2,{'Assumed patch-variance','multiplier'});
title(axes2,'(b) Patch only','FontSize',9,'FontWeight','bold');
lg=legend(axes1,h,[legendNames {'Nominal 95%'}],'Orientation','horizontal',...
 'NumColumns',3,'Box','off','FontSize',9);
lg.Units='normalized';lg.Position=[.15 .035 .83 .075];
end

function q=metric(DATA,condition,method,block)
ss=DATA.base.summaries;a=[];
for k=1:numel(ss)
 if iscell(ss),s=ss{k};else,s=ss(k);end
 if strcmp(s.suite,'J11')&&s.spec.condition_id==condition,a=s;break;end
end
assert(~isempty(a),'Missing E03 condition %d',condition);m=[];
for k=1:numel(a.method)
 if iscell(a.method),s=a.method{k};else,s=a.method(k);end
 if strcmp(s.label,method),m=s;break;end
end
assert(~isempty(m),'Missing E03 treatment %s',method);
b=m.blocks.(block);
if isfield(b,'coverage_conditional')
 ix=find(abs(b.nominal-.95)<1e-12,1);coverage=b.coverage_conditional(ix);
else,coverage=b.coverage95;end
N=m.n_valid;hits=round(coverage*N);ci=prnc.Stats.wilson(hits,N);
q=struct('coverage',coverage,'N',N,'hits',hits,'lower',max(0,ci(1)),'upper',min(1,ci(2)));
end
