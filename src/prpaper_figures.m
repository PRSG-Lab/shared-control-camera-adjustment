function manifest = prpaper_figures(data,analysis,destination,opt)
%PRPAPER_FIGURES Rebuild every current manuscript and SI figure in MATLAB.
% Inputs are computed data, never rendered artwork. The same path accepts
% reference summaries or a fresh run; every panel exports its source arrays.
% Main numerical Figures 2--6 follow v0.19; archived companion figures S1--S13.
% Reference shapes in Figure 5/S13 do NOT classify individual trials.
if nargin<4, opt=struct; end
if ~isfield(opt,'dpi'), opt.dpi=600; end
if ~isfield(opt,'visible'), opt.visible='off'; end
if ~isfield(opt,'closeFigures'), opt.closeFigures=true; end
if ~isfield(opt,'formats'), opt.formats={'png','pdf','fig'}; end
if ~isfield(opt,'figure_ids'), opt.figure_ids={}; end
if ~exist(destination,'dir'), mkdir(destination); end
D=data.base.figure_data;
manifest=repmat(struct('id','','caption','','source','','files',struct(),'data_file',''),0,1);
% The workflow is constructed as editable native shapes, not an embedded PNG.
if wanted('Figure1')
 [f,p]=workflow(opt); emit(f,'Figure1',p,'Study design and completed analysis branches','The simulation workflow combines analytical checks, paired camera estimation and assessment of camera and target uncertainty.');
end
if wanted('Figure2')
 [f,p]=panelgrid(D,{'F03',3;'F04',1;'F04',2;'F07',1},2,2,[190 152],opt,'reduced');
 emit(f,'Figure2',p,'Analytical/reduced-camera verification; F03/F04/F07','Control density, independent planes, depth diversity and global datum uncertainty affect the reduced-camera precision differently.');
end
if wanted('Figure3')
 [f,p]=prpaper_figure3(data,opt); emit(f,'Figure3',p,'E03/J11 c002 combined omission and c001 patch-variance scaling','Coverage under structural covariance omission and assumed patch-translation variance in separate experiments.');
end
if wanted('Figure4')
 [f,p]=panelgrid(D,{'F08',1;'F08',4;'F10',1;'F10',3},2,2,[190 157],opt,'noise');
 emit(f,'Figure4',p,'E02 and E04; F08/F10','Noise-scale and geometry-population experiments show geometry-dependent undercoverage of local camera confidence regions.');
end
if wanted('Figure5') || wanted('FigureS13')
 chart=chartdata(data.focal);
 if wanted('Figure5')
  [f,p]=charts(chart,opt); emit(f,'Figure5',p,'E02; narrow geometry G3, native focal-coordinate postprocessing','Paired focal-coordinate displays and full-camera Wald tests reveal coordinate sensitivity in the narrow noise-sweep experiment.');
 end
 if wanted('FigureS13')
  [f,p]=referenceshapes(chart,opt); emit(f,'FigureS13',p,'E02; mean fitted covariance, Schur complement and nonlinear boundary mapping','Illustrative mean-covariance outlines and focal-axis extents distinguish marginal regions, joint slices and nonlinear coordinate mapping.');
 end
end
if wanted('Figure6') || wanted('FigureS9')
 T=targetrows(data.revision.postprocess);
 if wanted('Figure6')
  [f,p]=targets(T,data.revision.postprocess,opt); emit(f,'Figure6',p,'E07; saved-camera target propagation','Target errors and pointwise coverage vary with depth and plane tilt under narrow control geometry.');
 end
 if wanted('FigureS9')
  [f,p]=imagetargets(T,opt); emit(f,'FigureS9',p,'E07; saved-camera target propagation','Image-target error and coverage are compared across reference, narrow-depth and global-translation conditions.');
 end
end
spec={...
 'FigureS1',{'F01',1;'F01',2},1,2,[190 97],'hidden','Hidden shared modes and camera parameter blocks determine analytical position scatter.';...
 'FigureS2',{'F02',1;'F02',2;'F02',3;'F02',4},2,2,[190 165],'linear','Linear Gaussian experiments verify the analytical covariance and residual-energy identities.';...
 'FigureS3',{'F03',3;'F03',4;'F04',1;'F04',3},2,2,[190 163],'reducedsupp','Reduced-camera experiments compare the effects of point density and independently supported planes.';...
 'FigureS4',{'F13',1;'F13',2;'F13',3;'F13',4},2,2,[190 163],'similarity','Shared similarity perturbations affect camera scatter and coverage across control-point counts.';...
 'FigureS5',{'F14',1;'F14',2;'F14',3;'F14',4},2,2,[190 169],'sources','Shared-error source experiments compare camera scatter, coverage and variance contributions.';...
 'FigureS6',{'F12',1;'F12',2;'F12',3;'F12',4},2,2,[190 168],'nees','Supplementary diagnostics compare coverage, normalised estimation errors and parameter-block uncertainty.';...
 'FigureS11',{'F11',1;'F11',2;'F11',3;'F11',4},2,2,[190 173],'residual','Residual diagnostics and position coverage are compared across noise, geometry and shared-error conditions.'};
for i=1:size(spec,1)
 id=spec{i,1}; if ~wanted(id), continue; end
 [f,p]=panelgrid(D,spec{i,2},spec{i,3},spec{i,4},spec{i,5},opt,spec{i,6});
 emit(f,id,p,strjoin(unique(string(spec{i,2}(:,1))),'; '),spec{i,7});
end
if wanted('FigureS7')
 [f,p]=jointdiagnostics(data.revision.postprocess,opt); emit(f,'FigureS7',p,'E01/E02/E03; fixed Gaussian and nonlinear diagnostics','Fixed-design Gaussian, fixed-covariance nonlinear and fitted-covariance diagnostics separate sources of joint undercoverage.');
end
if wanted('FigureS8')
 [f,p]=biasfigure(data.revision.bias,opt); emit(f,'FigureS8',p,'E02; directional second-order bias diagnostic','Second-order bias predictions are compared with empirical camera biases in units of Monte Carlo standard error.');
end
if wanted('FigureS10')
 [f,p]=covariancescale(D,opt); emit(f,'FigureS10',p,'E03; F09 panels 1--2','Camera and position coverage respond differently to shared-variance misspecification and simplified covariance treatments.');
end
if wanted('FigureS12')
 [f,p]=rotationfigure(data.revision.rotation,opt); emit(f,'FigureS12',p,'E05; selected stronger-rotation experiments','Stronger shared rotations increase covariance-omission effects as the number of control points grows.');
end
% Publication cover artwork is optional and has no numerical content.
if isfield(opt,'graphical_abstract') && opt.graphical_abstract
 [f,p]=graphicalabstract(opt); emit(f,'GraphicalAbstract',p,'Study message','Shared control errors require uncertainty assessment for the intended output.');
end
save(fullfile(destination,'figure_manifest.mat'),'manifest');
fid=fopen(fullfile(destination,'figure_manifest.json'),'w'); cleaner=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(manifest,'PrettyPrint',true),'char');clear cleaner
fid=fopen(fullfile(destination,'captions.txt'),'w'); cleaner=onCleanup(@()fclose(fid));
for k=1:numel(manifest), fprintf(fid,'%s. %s\n\n',manifest(k).id,manifest(k).caption); end
clear cleaner

 function yes=wanted(id)
  if strcmp(id,'Figure1')&&(~isfield(opt,'include_workflow')||~opt.include_workflow),yes=false;return;end
  yes=isempty(opt.figure_ids)||any(strcmp(string(opt.figure_ids),id));
 end
 function emit(fig,id,payload,source,caption)
  hh=findall(fig,'-property','FontSize');
  for kk=1:numel(hh),if hh(kk).FontSize<9,hh(kk).FontSize=9;end,end
  drawnow;
  captions=jsondecode(fileread(fullfile(prpaper_setup(),'docs','manuscript_captions.json')));
  if isfield(captions,id),caption=captions.(id);end
  payload.figure_id=id; payload.source=source; payload.caption=caption;
  payload.graphics=graphicsdata(fig); payload.created_utc=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
  payload.note='Saved numeric arrays reproduce this figure; two-dimensional reference outlines are illustrative, not individual trial tests.';
  path=fullfile(destination,[id '_data.mat']);save(path,'payload','-v7.3');
  files=struct;
  for e=1:numel(opt.formats)
   ext=char(opt.formats{e}); fn=fullfile(destination,[id '.' ext]);
   switch lower(ext)
    case 'fig', savefig(fig,fn);
    case 'png', prpaper_plot_export_png(fig,fn,opt.dpi);
    case 'pdf', exportgraphics(fig,fn,'ContentType','vector','BackgroundColor','white');
    otherwise, error('prpaper:FigureFormat','Unsupported figure format: %s',ext);
   end
   files.(ext)=[id '.' ext];
  end
  row=struct('id',id,'caption',caption,'source',char(source),'files',files,'data_file',[id '_data.mat']);
  manifest(end+1,1)=row;
  if opt.closeFigures, close(fig); end
  fprintf('Saved %s (%d dpi)\n',id,opt.dpi);
 end
end

function [f,p]=panelgrid(D,mapping,nr,nc,sz,opt,kind)
f=newfigure(sz,opt); tl=tiledlayout(f,nr,nc,'TileSpacing','compact','Padding','compact');p=struct('panels',{{}},'mapping',{mapping});
for i=1:size(mapping,1)
 src=D.(mapping{i,1}); pp=item(src.panels,mapping{i,2});
 if strcmp(kind,'residual')&&i<4
  pp.xlabel='Condition';pp.xlabels={'Noise .1','Noise .3','Noise 1','Noise 2','Depth .02','Depth .05','Depth .30','Count 13','Count 60','Global 13','Global 30','Global 60'};
 end
 ax=nexttile(tl);renderpanel(ax,pp,i,kind);p.panels{i}=pp;
end
end

function renderpanel(ax,p,i,kind)
P=palette();hold(ax,'on'); axisstyle(ax);ttl='';
if isfield(p,'subtitle')&&~isempty(p.subtitle),ttl=cleanlabel(p.subtitle);end
if strcmp(kind,'reduced'),tt={'Point density','Independent planes','Depth diversity','Global datum'};ttl=tt{i};end
if strcmp(kind,'noise'),tt={'Noise scale','Narrow geometry','Individual control layouts','Geometry populations'};ttl=tt{i};end
if strcmp(kind,'hidden'),tt={'Hidden shared modes','Parameter blocks'};ttl=tt{i};end
if strcmp(kind,'residual'),tt={'Residual variance factor','Residual-test rejection','Position coverage','Hidden variance and residuals'};ttl=tt{i};end
if strcmp(p.type,'heat')
 imagesc(ax,double(p.matrix));axis(ax,'xy');axis(ax,'tight');colormap(ax,parula);cb=colorbar(ax);cb.FontSize=8;
 if isnumeric(p.reference)&&numel(p.reference)==2,clim(ax,p.reference);end
 if strcmp(kind,'hidden'),cb.Label.String='log_{10}(1 + eigenvalue)';xticks(ax,[1 3 5 7 9 12]);else,cb.Label.String='Coverage';end
 if ~isempty(p.xlabels),xticks(ax,1:numel(p.xlabels));xticklabels(ax,labels(p.xlabels));xtickangle(ax,30);end
 if ~isempty(p.ylabels),yticks(ax,1:numel(p.ylabels));yticklabels(ax,labels(p.ylabels));end
 if isempty(p.ylabels),ylabel(ax,axislabel(p.ylabel));end
 xlabel(ax,axislabel(p.xlabel));title(ax,sprintf('(%c) %s','a'+i-1,ttl),'FontWeight','bold');return
end
for j=1:numel(p.series)
 s=item(p.series,j);x=double(s.x(:));y=double(s.y(:));name=cleanlabel(s.label);c=seriescolor(s.label,j,P);mk='os^d';mk=mk(mod(j-1,4)+1);ls='-';vis='on';
 if contains(s.label,'predicted')||startsWith(s.label,'Theory')||contains(lower(s.label),'limit'),ls='--';end
 if contains(s.label,'Slope 1'),ls=':';mk='none';end
 if ismember(kind,{'reduced','reducedsupp'})
  c=P(ceil(j/2),:);if startsWith(s.label,'Floor'),ls='--';mk='none';else,mk='o';end
 end
 if strcmp(kind,'linear')&&ismember(i,[1 4])
  if startsWith(s.label,'Theory'),ls='-';mk='none';v=regexp(s.label,'[^ ]+$','match','once');if i==1,name=['\rho = ' v];else,name=['a = ' v];end;else,ls='none';vis='off';end
 end
 if isfield(s,'lower')&&numel(s.lower)==numel(y)&&isfield(s,'upper')&&numel(s.upper)==numel(y)
  errorbar(ax,x,y,max(0,y-double(s.lower(:))),max(0,double(s.upper(:))-y),'Color',c,'Marker',mk,'LineStyle',ls,'DisplayName',name,'MarkerSize',3.5,'CapSize',3,'LineWidth',1,'HandleVisibility',vis);
 else
  plot(ax,x,y,'Color',c,'Marker',mk,'LineStyle',ls,'DisplayName',name,'MarkerSize',3.5,'LineWidth',1.05,'MarkerIndices',1:max(1,floor(numel(x)/25)):numel(x),'HandleVisibility',vis);
 end
end
if isnumeric(p.reference)&&isscalar(p.reference)&&isfinite(p.reference),yline(ax,p.reference,':','Color',[.3 .3 .3],'HandleVisibility','off');end
if contains(p.scale,'logx'),set(ax,'XScale','log');end
if contains(p.scale,'logy'),set(ax,'YScale','log');end
xlabel(ax,axislabel(p.xlabel));ylabel(ax,axislabel(p.ylabel));
if ~isempty(p.xlabels)
 xticks(ax,1:numel(p.xlabels));xticklabels(ax,labels(p.xlabels));if numel(p.xlabels)>3,xtickangle(ax,35);end
elseif numel(p.series)>0
 s=item(p.series,1);if numel(s.x)<9&&~contains(p.scale,'log'),xticks(ax,s.x);end
end
if contains(lower(p.ylabel),'coverage')&&~contains(lower(p.ylabel),'difference'),ylim(ax,[-.035 1.035]);end
if strcmp(kind,'reduced')&&ismember(i,[1 3])
 set(ax,'XScale','log');s=item(p.series,1);xticks(ax,s.x);xticklabels(ax,compose('%g',s.x));
elseif strcmp(kind,'reduced')&&i==2,xticks(ax,[2 4 8 16]);
elseif strcmp(kind,'reducedsupp')&&i<=2,set(ax,'XScale','log');xticks(ax,[4 10 30 100 300 1000]);
elseif strcmp(kind,'nees')&&i==2
 set(ax,'XScale','log','YScale','log');plot(ax,[1 40],[1 40],':k','DisplayName','1:1 reference');
elseif strcmp(kind,'nees')&&i==3,set(ax,'YScale','log');
end
if (strcmp(kind,'linear')&&i==2)||(strcmp(kind,'residual')&&i==4),xticks(ax,0:2:10);end
if strcmp(kind,'hidden')&&i==2,xticklabels(ax,{'EOP','+ f','+ distortion','+ pp'});xtickangle(ax,25);end
if strcmp(kind,'hidden')&&i==1,xticks(ax,[1 3 5 7 9 12]);end
lg=legend(ax,'Location','best','FontSize',8,'Box','off','Interpreter','tex');
if numel(p.series)>5,lg.NumColumns=2;end
if strcmp(kind,'reduced')
 locations={'east','northeast','northeast','northwest'};lg.Location=locations{i};
 if ismember(i,[1 3]),s=item(p.series,1);xlim(ax,[min(s.x)*.84 max(s.x)*1.15]);
 elseif i==2,xlim(ax,[1.5 16.5]);else,xlim(ax,[-.003 .103]);end
end
if strcmp(kind,'noise')
 locations={'southwest','southwest','southeast','west'};lg.Location=locations{i};
 if i<3,s=item(p.series,1);xlim(ax,[min(s.x)*.85 max(s.x)*1.15]);
 elseif i==3,xlim(ax,[.5 20.5]);else,xlim(ax,[.9 4.1]);end
end
if strcmp(kind,'sources')&&i==1,ylim(ax,[-.025 .85]);lg.Location='northeast';lg.ItemTokenSize=[10 8];end
if strcmp(kind,'hidden')&&i==2,lg.Location='southeast';end
if strcmp(kind,'linear')&&i==4,lg.Location='east';end
if strcmp(kind,'similarity')&&mod(i,2)==1,lg.Location='northeast';lg.NumColumns=1;lg.ItemTokenSize=[12 8];end
if strcmp(kind,'sources')&&i==2,lg.Location='east';end
if strcmp(kind,'nees')&&i==2,lg.Location='southoutside';lg.NumColumns=2;lg.ItemTokenSize=[12 8];end
if strcmp(kind,'residual')&&i==2,lg.Location='west';end
title(ax,sprintf('(%c) %s','a'+i-1,ttl),'FontWeight','bold','FontSize',9);
end

function [f,p]=omission(D,opt)
f=newfigure([190 98],opt);ax=axes(f,'Position',[.33 .24 .64 .66]);hold(ax,'on');axisstyle(ax);P=palette();p=struct('series',{{}});
names={'Full camera (10 parameters)','Camera position (3 coordinates)'};yy=4:-1:1;
for j=1:2
 pp=item(D.F09.panels,j+2);s=item(pp.series,1);v=100*s.y(:);lo=max(0,100*s.lower(:));hi=min(100,100*s.upper(:));y=yy+(1.5-j)*.28;
 markers='od';errorbar(ax,v,y,max(0,v-lo),max(0,hi-v),'horizontal','LineStyle','none','Marker',markers(j),'Color',P(j,:),'MarkerSize',5,'CapSize',5,'LineWidth',1.1,'DisplayName',names{j});
 for k=1:numel(v),text(ax,hi(k)+2,y(k),sprintf('%.1f%%',floor(v(k)*10+.5+1e-9)/10),'FontSize',8,'Color',P(j,:),'VerticalAlignment','middle');end
 p.series{j}=struct('x',v,'y',y,'lower',lo,'upper',hi,'label',names{j});
end
xline(ax,95,':','HandleVisibility','off');text(ax,95,4.55,'95% nominal','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8,'Color',[.3 .3 .3]);
yticks(ax,yy(end:-1:1));yticklabels(ax,{'Both components omitted','Patch component omitted','Global component omitted','Complete covariance'});
xlim(ax,[-3 114]);ylim(ax,[.5 4.9]);xticks(ax,0:20:100);xlabel(ax,'Coverage (%)');ax.YGrid='off';
lg=legend(ax,'Location','southoutside','Box','off','FontSize',8);lg.NumColumns=1;
end

function [f,p]=covariancescale(D,opt)
f=newfigure([190 109],opt);tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');P=palette();p=struct('source_panels',{{item(D.F09.panels,1),item(D.F09.panels,2)}});
for i=1:2
 ax=nexttile(tl);hold(ax,'on');axisstyle(ax);
 for j=1:2
  pp=item(D.F09.panels,j);s=item(pp.series,1);v=100*s.y(:);lo=100*s.lower(:);hi=100*s.upper(:);if i==1,ix=1:5;x=[.25 .5 1 2 4];ls='-';else,ix=[3 6 7 8];x=(1:4)+(j-1.5)*.18;ls='none';end
  ns={'Full camera','Camera position'};errorbar(ax,x,v(ix),max(0,v(ix)-lo(ix)),max(0,hi(ix)-v(ix)),'o','LineStyle',ls,'Color',P(j,:),'DisplayName',ns{j},'MarkerSize',4,'CapSize',4);
 end
 yline(ax,95,':','HandleVisibility','off');ylim(ax,[-3 103]);ylabel(ax,'Coverage (%)');
 if i==1,set(ax,'XScale','log');xticks(ax,[.25 .5 1 2 4]);xticklabels(ax,{'0.25','0.5','1','2','4'});xlim(ax,[.2 5]);xlabel(ax,'Assumed / true shared variance');title(ax,'(a) Shared variance magnitude');
 else,xticks(ax,1:4);xticklabels(ax,{'Full','Local','Marginal','Fixed-3D'});xtickangle(ax,30);xlim(ax,[.6 4.4]);xlabel(ax,'Covariance treatment');title(ax,'(b) Covariance treatments');end
 if i==1,lg=legend(ax,'Location','southoutside','Box','off');lg.Layout.Tile='south';lg.NumColumns=2;end
end
end

function [f,p]=workflow(opt)
% A native-vector rendering of the current seven-panel/six-stage schematic.
% Locations below are diagram coordinates, not measured or simulated samples.
f=newfigure([190 151],opt);ax=axes(f,'Position',[.01 .01 .98 .98]);hold(ax,'on');axis(ax,[0 1 0 1]);axis(ax,'off');
boxes=[.00 .765 .485 .23;.515 .765 .485 .23;.00 .495 .485 .245;.515 .495 .485 .245;.00 .300 1 .17;.00 .015 .485 .26;.515 .015 .485 .26];
heads={'1. Camera and control configuration','2. Observation covariance structure','3a. Analytical decomposition','3b. Nonlinear Monte Carlo adjustment','4. Control-design experiments','5. Camera uncertainty assessment','6. Measurement-level validation'};
P=palette();
for k=1:7
 b=boxes(k,:);rectangle(ax,'Position',b,'FaceColor','white','EdgeColor',[.22 .33 .42],'LineWidth',.75);
 rectangle(ax,'Position',[b(1) b(2)+b(4)-.04 b(3) .04],'FaceColor',[.79 .91 .97],'EdgeColor',[.22 .33 .42],'LineWidth',.75);
 text(ax,b(1)+b(3)/2,b(2)+b(4)-.02,heads{k},'FontSize',8.1,'FontWeight','bold','HorizontalAlignment','center','Interpreter','none');
end
% Camera icon and a stylised control plane.
cameraicon(ax,.035,.855,.065);xx=[.20 .24 .28 .32 .36];yy=[.83 .86 .89 .92 .95];
for j=1:5,plot(ax,xx(j)*ones(1,4),[.815 .845 .875 .905],'.','Color',P(1,:),'MarkerSize',5);end
for y=[.815 .905],plot(ax,[.095 .20],[.87 y],':','Color',[.5 .5 .5]);end
quiver(ax,.25,.85,.07,.015,0,'Color',P(1,:),'LineWidth',1,'MaxHeadSize',.4);quiver(ax,.25,.85,-.018,.035,0,'Color',P(2,:),'LineWidth',1,'MaxHeadSize',.6);
text(ax,.105,.793,'Local errors + shared translation / rotation / scale','FontSize',8,'HorizontalAlignment','left','Interpreter','none');
% Covariance matrix, with local diagonal and cross-point blocks.
x0=.555;y0=.798;side=.144;step=side/4;
for r=1:4,for c=1:4,co=[.98 .78 .72];if r==c,co=[.39 .71 .91];end;rectangle(ax,'Position',[x0+(c-1)*step y0+(4-r)*step step step],'FaceColor',co,'EdgeColor','white','LineWidth',.5);end,end
text(ax,.735,.902,'Local 3-D blocks','FontSize',8,'Color',P(1,:));text(ax,.735,.862,{'Shared cross-point','covariance blocks'},'FontSize',8,'Color',P(2,:));text(ax,.735,.806,'\Sigma = Q_{local} + BQ_bB^T','FontSize',8.4);
% Absorbed and residual components, with explicit conceptual arrows.
text(ax,.027,.660,{'Shared control','perturbation'},'FontSize',8,'HorizontalAlignment','left','Color',P(2,:));
diagramarrow(ax,[.133 .659],[.23 .674]);diagramarrow(ax,[.133 .645],[.23 .578]);
rectangle(ax,'Position',[.24 .635 .22 .065],'FaceColor',[.92 .97 1],'EdgeColor',P(1,:));text(ax,.35,.667,{'Absorbed by','camera change'},'HorizontalAlignment','center','FontSize',8);
rectangle(ax,'Position',[.24 .539 .22 .065],'FaceColor',[.96 .96 .96],'EdgeColor',P(1,:));text(ax,.35,.571,{'Visible in','residuals'},'HorizontalAlignment','center','FontSize',8);
text(ax,.242,.513,'Conditional uncertainty limits','FontSize',8,'HorizontalAlignment','left');
% Paired adjustment paths.
cameraicon(ax,.55,.62,.047);cameraicon(ax,.62,.62,.047);text(ax,.595,.564,{'Repeated noisy','observations'},'HorizontalAlignment','center','FontSize',8);
diagramarrow(ax,[.681 .64],[.733 .64]);methods={'Fixed-3D','GH local','GH marginal','GH full'};
for j=1:4
 y=.691-.046*j;rectangle(ax,'Position',[.751 y .222 .037],'FaceColor',[.89 .94 .97],'EdgeColor',P(j,:),'LineWidth',.6);text(ax,.862,y+.0185,methods{j},'HorizontalAlignment','center','FontSize',8);
end
% Design changes: point density, independent sources, depth diversity.
for xx=[.335 .665],plot(ax,[xx xx],[.314 .418],'-','Color',[.75 .75 .75]);end
text(ax,.165,.401,'Point density','HorizontalAlignment','center','FontSize',8,'FontWeight','bold');
plot(ax,[.045 .08 .115],[.355 .335 .355],'.','Color',P(1,:),'MarkerSize',8);diagramarrow(ax,[.14 .35],[.205 .35]);
for j=1:4,plot(ax,.23+(0:3)*.018,(.319+j*.014)*ones(1,4),'.','Color',P(1,:),'MarkerSize',4);end
text(ax,.5,.401,'Independent sources','HorizontalAlignment','center','FontSize',8,'FontWeight','bold');
for j=1:3,plot(ax,.394+.058*j+[-.009 .006 .013],.350+[-.018 0 .020],'.','Color',P(j,:),'MarkerSize',8);end
text(ax,.834,.401,'Depth diversity','HorizontalAlignment','center','FontSize',8,'FontWeight','bold');
for j=1:3,x=.725+.078*j;patch(ax,x+[-.017 .017 .017 -.017],[.319 .325 .379 .373],P(j,:),'FaceAlpha',.25,'EdgeColor',P(j,:));end
% Confidence region / empirical estimates are schematic, explicitly labelled.
t=linspace(0,2*pi,181);plot(ax,.135+.095*cos(t),.140+.035*sin(t),'Color',P(1,:),'LineWidth',1);plot(ax,.135,.14,'k.','MarkerSize',7);
text(ax,.135,.204,{'Local Wald','confidence region'},'HorizontalAlignment','center','FontSize',8);diagramarrow(ax,[.238 .14],[.275 .14]);
u=(1:17)';cloudx=.358+.07*cos(u*2.4).*sqrt(u/17);cloudy=.142+.040*sin(u*2.4).*sqrt(u/17);plot(ax,cloudx,cloudy,'.','Color',P(2,:),'MarkerSize',4);
text(ax,.361,.204,{'Monte Carlo','coverage'},'HorizontalAlignment','center','FontSize',8);text(ax,.242,.065,'Native log-focal and direct-focal charts','HorizontalAlignment','center','FontSize',8);text(ax,.242,.036,'Illustrative display; numerical tests use all parameters','HorizontalAlignment','center','FontSize',8);
% Target depth and tilt.
cameraicon(ax,.544,.133,.045);
for j=1:3,x=.66+(j-1)*.095;patch(ax,x+[-.018 .018 .018 -.018],[.096 .107 .192 .181],[.69 .87 .94],'FaceAlpha',.65,'EdgeColor',P(1,:));plot(ax,x*ones(1,3),[.12 .145 .17],'k.','MarkerSize',5);end
plot(ax,[.60 .92],[.15 .15],':','Color',[.55 .55 .55]);text(ax,.78,.222,'Depth extrapolation and oblique planes','HorizontalAlignment','center','FontSize',8);text(ax,.765,.058,{'Absolute error and pointwise coverage','of image and object-space targets'},'HorizontalAlignment','center','FontSize',8);
% Causal stage links in the white gutters.
for x=[.242 .757],diagramarrow(ax,[x .762],[x .741]);diagramarrow(ax,[x .492],[x .472]);diagramarrow(ax,[x .296],[x .278]);end
p=struct('stage_labels',{heads},'panel_positions',boxes,'schematic_only',true,'covariance_definition','Sigma = Q_local + B Q_b B^T','diagram_point_coordinates',[cloudx cloudy],'note','Diagram points and shapes illustrate concepts and are not empirical results.');
end

function cameraicon(ax,x,y,w)
rectangle(ax,'Position',[x y w .036],'FaceColor',[.23 .25 .28],'EdgeColor',[.1 .1 .1],'Curvature',.10);rectangle(ax,'Position',[x+w*.12 y+.035 w*.35 .012],'FaceColor',[.23 .25 .28],'EdgeColor',[.1 .1 .1]);
t=linspace(0,2*pi,45);patch(ax,x+w*.63+w*.27*cos(t),y+.018+.018*sin(t),[.7 .78 .82],'EdgeColor',[.1 .1 .1]);
end

function diagramarrow(ax,a,b)
quiver(ax,a(1),a(2),b(1)-a(1),b(2)-a(2),0,'Color',[.30 .39 .44],'MaxHeadSize',.5,'LineWidth',.8);
end

function [f,p]=graphicalabstract(opt)
f=newfigure([60 50],opt);ax=axes(f,'Position',[.02 .02 .96 .96]);axis(ax,[0 1 0 1]);axis(ax,'off');hold(ax,'on');
texts={'Shared control errors',sprintf('Small residuals\nUncertain camera'),sprintf('Validate the\nintended output')};ys=[.72 .38 .04];
for k=1:3,rectangle(ax,'Position',[.02 ys(k) .96 .23],'Curvature',.12,'FaceColor',[.91 .95 .97],'EdgeColor',[.22 .33 .42]);text(ax,.5,ys(k)+.115,texts{k},'HorizontalAlignment','center','FontSize',9);end
for y=[.7 .36],quiver(ax,.5,y,0,-.07,0,'Color',[.22 .33 .42],'MaxHeadSize',.9);end
p=struct('text',{texts});
end

function C=chartdata(A)
% Arithmetic means of each chart's OWN native full fitted covariance.
E=double(A.error_log_truth_minus_fit);F=double(A.error_direct_truth_minus_fit);n=size(E,1);f0=double(A.f_true);
CL=normalcov(A.covariance_log,n);CF=normalcov(A.covariance_direct,n);
T=eye(10);T(1:3,1:3)=A.R_true;TF=T;TF(7,7)=1/f0;
CB=zeros(10);DB=zeros(10);
for i=1:n,CB=CB+T*CL(:,:,i)*T';DB=DB+TF*CF(:,:,i)*TF';end
CB=(CB+CB')/(2*n);DB=(DB+DB')/(2*n);J=[3 7];K=setdiff(1:10,J);M=CB(J,J);MD=DB(J,J);
% Scaled precision avoids loss of accuracy caused by pixel/metre units.
P=scaledinverse(CB);S=scaledinverse(P(J,J));Sschur=M-CB(J,K)*(CB(K,K)\CB(K,J));
assert(norm(S-Sschur,'fro')/norm(S,'fro')<1e-6,'Schur-complement verification failed.');
H=whiten(M);HD=whiten(MD);d=double(A.optical_position_error(:));UL=(H*[d E(:,7)]')';UD=(HD*[d F(:,7)/f0]')';
q2=2*gammaincinv(.95,1);q10=2*gammaincinv(.95,5);wl=double(A.W_log(:));wd=double(A.W_direct(:));il=wl<=q10;idf=wd<=q10;
if isfield(A,'inside_log'),assert(isequal(il,logical(A.inside_log(:))),'Log-focal decisions disagree.');end
if isfield(A,'inside_direct'),assert(isequal(idf,logical(A.inside_direct(:))),'Direct-focal decisions disagree.');end
marg=ellipse(M,q2);sl=ellipse(S,q10);direct=sl;direct(2,:)=f0*sl(2,:);mapped=sl;mapped(2,:)=f0*expm1(sl(2,:));
C=struct('n',n,'E',E,'F',F,'f_true',f0,'optical_position_error',d,'mean_log_covariance',CB,'mean_scaled_direct_covariance',DB,'M',M,'M_direct',MD,'S',S,'H',H,'H_direct',HD,'uw_log',UL,'uw_direct',UD,'W_log',wl,'W_direct',wd,'inside_log',il,'inside_direct',idf,'chi2_2_95',q2,'chi2_10_95',q10,'marginal_boundary',H*marg,'slice_boundary',H*sl,'direct_reference_slice',direct,'mapped_log_reference_slice',mapped);
C.paired_counts=[sum(il&idf),sum(~il&idf),sum(il&~idf),sum(~il&~idf)];
C.median_absolute_optical_error=median(abs(d),'omitnan');C.median_absolute_focal_error=median(abs(F(:,7)),'omitnan');
end

function [f,p]=charts(C,opt)
f=newfigure([190 77],opt);P=palette();ax=gobjects(1,3);pos=[.085 .275 .235 .48;.405 .275 .235 .48;.745 .275 .235 .48];
lim=4.7;clipped=[sum(any(abs(C.uw_log)>lim,2)),sum(any(abs(C.uw_direct)>lim,2))];
for i=1:3,ax(i)=axes(f,'Position',pos(i,:));hold(ax(i),'on');axisstyle(ax(i));end
u={C.uw_log,C.uw_direct};tit={'(a) Log-focal display','(b) Direct-focal display'};
for i=1:2
 cloud(ax(i),u{i}(:,1),u{i}(:,2),C.inside_log);
 th=linspace(0,2*pi,1441);plot(ax(i),sqrt(C.chi2_2_95)*cos(th),sqrt(C.chi2_2_95)*sin(th),'Color',P(1,:),'LineWidth',1.1);
 axis(ax(i),'equal');xlim(ax(i),[-lim lim]);ylim(ax(i),[-lim lim]);xticks(ax(i),-4:2:4);yticks(ax(i),-4:2:4);
 xlabel(ax(i),{'Along-ellipse component','(marginal SD)'},'FontSize',8);ylabel(ax(i),{'Across-ellipse component','(marginal SD)'},'FontSize',8);
 title(ax(i),{tit{i},'Illustrative'},'FontSize',8.5);text(ax(i),0,-3.85,'2-D reference outline','HorizontalAlignment','center','Color',P(1,:),'FontSize',8);
end
ax3=ax(3);cloud(ax3,C.W_log,C.W_direct,C.inside_log);set(ax3,'XScale','log','YScale','log');
xlim(ax3,[.8 4e4]);ylim(ax3,[.8 900]);plot(ax3,[.8 900],[.8 900],'-','Color',[.55 .55 .55],'LineWidth',.7);
xline(ax3,C.chi2_10_95,'--','Color',P(1,:),'LineWidth',.8);yline(ax3,C.chi2_10_95,'--','Color',P(1,:),'LineWidth',.8);
xticks(ax3,[1 10 100 1000 10000]);yticks(ax3,[1 10 100]);xlabel(ax3,{'Squared Mahalanobis','distance (log-focal)'},'FontSize',8);ylabel(ax3,{'Squared Mahalanobis','distance (direct-focal)'},'FontSize',8);title(ax3,{'(c) Paired 10-D tests','Trial-specific'},'FontSize',8.5);
c=C.paired_counts;cornertext(ax3,.035,.96,sprintf('Log only\n%d',c(3)),'left','top');cornertext(ax3,.96,.96,sprintf('Both out\n%d',c(4)),'right','top');cornertext(ax3,.035,.045,sprintf('Both in\n%d',c(1)),'left','bottom');cornertext(ax3,.96,.045,sprintf('Direct only\n%d',c(2)),'right','bottom');
legendkey(f,C,.93);
annotation(f,'textbox',[.03 .005 .95 .08],'String',sprintf('Outside display windows: (a) %d; (b) %d; all %s trials remain in paired tests',clipped(1),clipped(2),num2str(C.n)),'EdgeColor','none','HorizontalAlignment','center','FontSize',8,'Interpreter','none');
p=C;p.clipped_display_counts=clipped;p.display_limit_sd=lim;
end

function [f,p]=referenceshapes(C,opt)
f=newfigure([190 83],opt);P=palette();a=axes(f,'Position',[.105 .26 .33 .51]);hold(a,'on');axisstyle(a);cloud(a,C.uw_log(:,1),C.uw_log(:,2),C.inside_log);
plot(a,C.marginal_boundary(1,:),C.marginal_boundary(2,:),'Color',P(1,:),'LineWidth',1.1);
plot(a,C.slice_boundary(1,:),C.slice_boundary(2,:),'--','Color',P(1,:),'LineWidth',1.1);axis(a,'equal');xlim(a,[-4.7 4.7]);ylim(a,[-4.7 4.7]);xticks(a,-4:2:4);yticks(a,-4:2:4);
xlabel(a,{'Along-ellipse component','(marginal SD)'});ylabel(a,{'Across-ellipse component','(marginal SD)'});title(a,{'(a) Reference outlines','Illustrative; mean log covariance'},'FontSize',8.5);
text(a,0,-1.3,'2-D marginal','HorizontalAlignment','center','Color',P(1,:),'FontSize',8);text(a,0,-3.3,'10-D zero-offset slice','HorizontalAlignment','center','Color',P(1,:),'FontSize',8);
a=axes(f,'Position',[.60 .26 .37 .51]);hold(a,'on');axisstyle(a);grid(a,'off');ylim(a,[0 4.15]);xlim(a,[-2800 2400]);xticks(a,[-2000 0 2000]);yticks(a,[]);xlabel(a,'Focal-length offset (pixels)');title(a,{'(b) Focal-axis extents',sprintf('Illustrative; reference f = %g px',C.f_true)},'FontSize',8.5);
arr={C.direct_reference_slice,C.mapped_log_reference_slice};ns={'Direct-focal slice','Mapped log-focal'};sty={'-','--'};
for i=1:2
 pts=arr{i};lo=min(pts(2,:));hi=max(pts(2,:));y=4.25-1.1*i;
 plot(a,[lo hi],[y y],sty{i},'Color',P(1,:),'LineWidth',1.6);plot(a,[lo lo],[y-.08 y+.08],'Color',P(1,:));plot(a,[hi hi],[y-.08 y+.08],'Color',P(1,:));
 text(a,0,y+.18,ns{i},'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8);text(a,lo,y-.15,sprintf('%.0f',lo),'HorizontalAlignment','center','VerticalAlignment','top','FontSize',8);text(a,hi,y-.15,sprintf('+%.0f',hi),'HorizontalAlignment','center','VerticalAlignment','top','FontSize',8);
end
edges=-2800:100:2400;hin=histcounts(C.F(C.inside_log,7),edges);hout=histcounts(C.F(~C.inside_log,7),edges);scale=1.05/max([hin hout 1]);
histogram(a,'BinEdges',edges,'BinCounts',hin*scale,'FaceColor',[.5 .5 .5],'FaceAlpha',.42,'EdgeColor','none');histogram(a,'BinEdges',edges,'BinCounts',hout*scale,'FaceColor',P(2,:),'FaceAlpha',.42,'EdgeColor','none');text(a,.03,.33,'Saved focal errors','Units','normalized','FontSize',8);
legendkey(f,C,.93);annotation(f,'textbox',[.03 .008 .95 .07],'String','Reference outlines and projected extents do not classify individual trials','EdgeColor','none','HorizontalAlignment','center','FontSize',8);
p=C;p.histogram=struct('edges',edges,'inside_log_counts',hin,'outside_log_counts',hout,'display_scale',scale);
end

function legendkey(f,C,y)
a=axes(f,'Position',[.14 y-.01 .74 .045],'Visible','off');hold(a,'on');
h1=plot(a,nan,nan,'o','MarkerSize',3,'Color',[.5 .5 .5],'LineStyle','none');h2=plot(a,nan,nan,'^','MarkerSize',3,'Color',[.8353 .3686 0],'LineStyle','none');
lg=legend(a,[h1 h2],{sprintf('Inside 10-D log-focal region (%d)',sum(C.inside_log)),sprintf('Outside 10-D log-focal region (%d)',sum(~C.inside_log))},'NumColumns',2,'Box','off','FontSize',8,'Location','north');lg.AutoUpdate='off';
end

function cloud(ax,x,y,inside)
scatter(ax,x(inside),y(inside),4,[.498 .498 .498],'o','filled','MarkerFaceAlpha',.42,'MarkerEdgeAlpha',0);scatter(ax,x(~inside),y(~inside),4.5,[.8353 .3686 0],'^','filled','MarkerFaceAlpha',.42,'MarkerEdgeAlpha',0);
end

function cornertext(ax,x,y,s,ha,va)
text(ax,x,y,s,'Units','normalized','HorizontalAlignment',ha,'VerticalAlignment',va,'FontSize',8,'BackgroundColor','white','Margin',.1);
end

function T=targetrows(P)
cc=P.target_conditions;T=table;
for k=1:numel(cc),r=item(cc,k);T=[T;as_table(r.rows)];end %#ok<AGROW>
for v={'condition','method','kind','target'},T.(v{1})=string(T.(v{1}));end
end

function [f,p]=targets(T,R,opt)
f=newfigure([190 155],opt);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');p=struct('target_rows',T,'range_panels',{{}},'heatmaps',{{}});
for i=1:2
 ax=nexttile(tl);metric={'rmse','coverage'};p.range_panels{i}=targetranges(ax,T,'J09c005','plane',metric{i});
 if i==1,title(ax,'(a) Narrow geometry error');legend(ax,'Location','northwest','Box','off');else,title(ax,'(b) Narrow geometry coverage');ylim(ax,[20 101]);end
end
sel=T(endsWith(T.condition,'J09c005')&T.method=="GH_FULL"&T.kind=="plane"&T.target=="depth20_tilt75",:);sel=sortrows(sel,'point');
ng=sqrt(height(sel));assert(ng==round(ng),'Target heatmap requires a square grid.');
% Engine point order is MATLAB column-major, x slow and y fast.
% Use actual image offsets from the saved target design, not guessed extents.
c=findcondition(R.target_conditions,'J09c005');targets_=c.targets;di=[];
for k=1:numel(targets_),z=item(targets_,k);if strcmp(z.design.id,'depth20_tilt75'),di=z.design;break;end,end
if isempty(di),error('prpaper:TargetDesign','Missing target plane design.');end
if isfield(di,'uv'),xy=double(di.uv);elseif isfield(di,'pixels'),xy=double(di.pixels);elseif isfield(di,'image_truth'),xy=double(di.image_truth);else,error('prpaper:TargetDesign','No target pixel coordinates.');end
if size(xy,1)~=2,xy=xy';end
xgrid=unique(xy(1,:));ygrid=unique(xy(2,:));
% Subtract principal-point offsets to describe rays relative to image centre.
xgrid=xgrid-mean(xgrid);ygrid=ygrid-mean(ygrid);
for j=1:2
 ax=nexttile(tl);axisstyle(ax);key={'rmse','coverage'};v=reshape(sel.(key{j}),ng,ng);if j==2,v=100*v;end
 imagesc(ax,xgrid,ygrid,v);axis(ax,'xy');axis(ax,'tight');colormap(ax,parula);cb=colorbar(ax);cb.FontSize=8;
 if j==1,set(ax,'ColorScale','log');cb.Label.String='RMSE (m)';title(ax,'(c) 75° plane RMSE');else,clim(ax,[90 96]);cb.Label.String='Coverage (%)';title(ax,'(d) 75° plane coverage');end
 xlabel(ax,'Image offset x (pixels)');ylabel(ax,'Image offset y (pixels)');p.heatmaps{j}=struct('x',xgrid,'y',ygrid,'values',v,'quantity',key{j});
end
end

function p=targetranges(ax,T,condition,kind,metric)
P=palette();hold(ax,'on');axisstyle(ax);keys={'depth10_tilt0','depth20_tilt0','depth40_tilt0','depth20_tilt60','depth20_tilt75'};labs={'10 m','20 m','40 m','60°','75°'};methods={'GH_LOCAL','GH_FULL'};p=struct('series',{{}},'condition',condition,'kind',kind,'metric',metric);range_values=[];
for j=1:2
 med=nan(1,5);lo=med;hi=med;
 for k=1:5,v=T.(metric)(endsWith(T.condition,condition)&T.method==methods{j}&T.kind==kind&T.target==keys{k});med(k)=median(v,'omitnan');lo(k)=min(v,[],'omitnan');hi(k)=max(v,[],'omitnan');end
 scale=1;if strcmp(metric,'coverage'),scale=100;end;med=scale*med;lo=scale*lo;hi=scale*hi;range_values=[range_values lo hi];x=(1:5)+(j-1.5)*.16;c=P(3-j,:);
 errorbar(ax,x,med,max(0,med-lo),max(0,hi-med),'o','LineStyle','none','Color',c,'MarkerSize',4,'CapSize',5,'DisplayName',cleanlabel(methods{j}));
 p.series{j}=struct('x',x,'median',med,'minimum',lo,'maximum',hi,'method',methods{j});
end
xticks(ax,1:5);xticklabels(ax,labs);xlim(ax,[.5 5.5]);xlabel(ax,'Target depth / oblique-plane tilt');
if strcmp(metric,'coverage'),yline(ax,95,':','HandleVisibility','off');ylim(ax,[-1 101]);ylabel(ax,'Coverage (%)');else,set(ax,'YScale','log');positive=range_values(isfinite(range_values)&range_values>0);if ~isempty(positive),ylim(ax,[min(positive)*.8 max(positive)*1.25]);end;if strcmp(kind,'plane'),ylabel(ax,'RMSE (m)');else,ylabel(ax,'RMSE (pixels)');end,end
end

function [f,p]=imagetargets(T,opt)
f=newfigure([190 185],opt);tl=tiledlayout(f,3,2,'TileSpacing','compact','Padding','compact');conds={'J09c003','J09c005','J09c012'};names={'Reference','Narrow depth','Global translation'};p=struct('panels',{{}});
for i=1:3,for j=1:2,ax=nexttile(tl);key={'rmse','coverage'};p.panels{end+1}=targetranges(ax,T,conds{i},'image',key{j});title(ax,sprintf('(%c) %s','a'+(i-1)*2+j-1,names{i}));if i==1&&j==1,legend(ax,'Location','northeast','Box','off');end,end,end
end

function [f,p]=jointdiagnostics(R,opt)
f=newfigure([190 156],opt);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');ax=nexttile(tl,[1 2]);hold(ax,'on');axisstyle(ax);P=palette();
sel={'J09c003','GH_LOCAL','Reference local';'J11c002','omit_global','Omitted global';'J09c005','GH_FULL','Narrow reference';'J10c014','GH_FULL','Narrow noise sweep'};v=zeros(4,3);dcell=cell(1,4);
for i=1:4
 d=findcondition(R.diagnostics,sel{i,1});q=findmethod(d.methods,sel{i,2});v(i,:)=[q.gaussian.coverage q.fixed_nominal_coverage q.full_coverage]*100;dcell{i}=q;
end
b=bar(ax,v,'grouped');b(1).FaceColor=P(3,:);b(2).FaceColor=P(2,:);b(3).FaceColor=P(1,:);yline(ax,95,':','HandleVisibility','off');xticks(ax,1:4);xticklabels(ax,sel(:,3));ylim(ax,[0 112]);ylabel(ax,'Full-camera coverage (%)');title(ax,'(a) Covariance and sampling effects');
lg=legend(ax,{'Gaussian fixed design','Nonlinear fixed covariance','Nonlinear fitted covariance'},'Location','northoutside','Orientation','horizontal','FontSize',8,'Box','off');lg.NumColumns=3;
g=dcell{2}.saved_generalized;eigv=double(g.covariance_eigenvalues(:));ax=nexttile(tl);axisstyle(ax);bar(ax,1:numel(eigv),eigv,'FaceColor',P(1,:));yline(ax,1,':');xticks(ax,[1 3 5 7 10]);xlabel(ax,'Generalised mode');ylabel(ax,'Empirical / reported variance');title(ax,'(b) Omitted-global modes');
ax=nexttile(tl);axisstyle(ax);imagesc(ax,g.block_coefficient_shares);axis(ax,'xy');clim(ax,[0 1]);colormap(ax,parula);colorbar(ax);yticks(ax,1:5);yticklabels(ax,{'Position','Rotation','Log focal','Distortion','Principal point'});xticks(ax,[1 3 5 7 10]);xlabel(ax,'Generalised mode');title(ax,'(c) Scaled coefficient shares');
p=struct('selection',{sel},'coverage_percent',v,'diagnostics',{dcell},'generalized_modes',g);
end

function [f,p]=biasfigure(R,opt)
f=newfigure([190 149],opt);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');P=palette();p=struct('geometries',{{}});
for i=1:numel(R.geometries)
 g=item(R.geometries,i);ax=nexttile(tl);hold(ax,'on');axisstyle(ax);pp=struct('geometry_id',g.geometry_id,'series',{{}});
 for j=1:numel(g.comparison)
  c=item(g.comparison,j);b=double(c.predicted_bias);emp=double(c.empirical_bias(:));se=double(c.standard_error(:));if size(b,1)~=numel(emp),b=b';end
  y=(b(:,end)-emp)./se;cc=[3 2 1];col=P(cc(min(j,3)),:);plot(ax,1:numel(y),y,'o-','Color',col,'DisplayName',sprintf('\\epsilon = %g',c.epsilon),'MarkerSize',3,'LineWidth',1);
  if j==1&&all(~isfinite(y)),text(ax,.5,.5,{'Second-order diagnostic incomplete','in this execution profile'},'Units','normalized','HorizontalAlignment','center','FontSize',8,'Color',[.4 .4 .4]);end
  pp.series{j}=struct('epsilon',c.epsilon,'parameter_index',(1:numel(y))','standardized_difference',y,'predicted_bias',b(:,end),'empirical_bias',emp,'standard_error',se);
 end
 yline(ax,1.96,'--','Color',[.4 .4 .4],'HandleVisibility','off');yline(ax,-1.96,'--','Color',[.4 .4 .4],'HandleVisibility','off');yline(ax,0,'-','Color',[.7 .7 .7],'HandleVisibility','off');
 ylim(ax,[-2.2 2.2]);xticks(ax,[1 3 5 7 10]);xlabel(ax,'Parameter index');ylabel(ax,'(Predicted - empirical bias) / SE');title(ax,sprintf('(%c) G%d','a'+i-1,g.geometry_id));
 if i==1,lg=legend(ax,'Location','south','Box','off','FontSize',8);lg.NumColumns=3;end;p.geometries{i}=pp;
end
end

function [f,p]=rotationfigure(R,opt)
T=table;for k=1:numel(R.conditions),r=item(R.conditions,k);T=[T;as_table(r.rows)];end %#ok<AGROW>
T.method=string(T.method);ang=unique(T.rotation_deg);assert(~isempty(ang),'No selected rotation magnitudes.');
nangle=numel(ang);f=newfigure([190 max(82,75.5*nangle)],opt);tl=tiledlayout(f,nangle,2,'TileSpacing','compact','Padding','compact');P=palette();p=struct('rows',T);
for i=1:nangle
 ax1=nexttile(tl);hold(ax1,'on');axisstyle(ax1);ax2=nexttile(tl);hold(ax2,'on');axisstyle(ax2);
 for j=1:2
  methods={'GH_LOCAL','GH_FULL'};q=T(abs(T.rotation_deg-ang(i))<1e-10&T.method==methods{j},:);q=sortrows(q,'points');n=q.points;c=P(3-j,:);nm=strrep(cleanlabel(methods{j}),'GH ','');
  plot(ax1,n,q.position_scatter,'o-','Color',c,'MarkerSize',4,'DisplayName',[nm ' empirical']);plot(ax1,n,q.predicted_position_scatter,'s--','Color',c,'MarkerSize',3,'DisplayName',[nm ' predicted']);
  v=100*q.full_coverage;errorbar(ax2,n,v,max(0,v-100*q.full_low),max(0,100*q.full_high-v),'o-','Color',c,'CapSize',4,'MarkerSize',4,'DisplayName',nm);
 end
 plot(ax1,n,q.shared_only_position_scatter,':kd','MarkerSize',3,'DisplayName','Shared only');ylim(ax1,[0 max(.44,1.1*max(T.position_scatter))]);ylabel(ax1,'Position scatter (m)');
 yline(ax2,95,':','HandleVisibility','off');ylim(ax2,[-2 104]);ylabel(ax2,'Full-camera coverage (%)');
 for a=[ax1 ax2],xticks(a,unique(T.points));xlabel(a,'Control point count');end
 title(ax1,sprintf('(%c) Rotation STD %g°','a'+2*(i-1),ang(i)));title(ax2,sprintf('(%c) Rotation STD %g°','b'+2*(i-1),ang(i)));
 lg=legend(ax1,'Location','northeast','Box','off','FontSize',8);lg.NumColumns=1;lg.ItemTokenSize=[12 8];legend(ax2,'Location','east','Box','off','FontSize',8);
end
end

function f=newfigure(mm,opt)
f=figure('WindowStyle','normal','Visible',opt.visible,'Color','white','Units','centimeters','Position',[1 1 mm/10],'PaperUnits','centimeters','PaperSize',mm/10,'InvertHardcopy','off');
set(f,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial','DefaultAxesFontSize',8.5,'DefaultTextFontSize',8.5,'DefaultAxesLabelFontSizeMultiplier',1,'DefaultAxesTitleFontSizeMultiplier',1.06,'DefaultAxesLineWidth',.65,'DefaultLineLineWidth',1.05);
end

function axisstyle(ax)
set(ax,'Box','off','FontSize',8.5,'LineWidth',.65,'TickDir','out','GridAlpha',.18,'MinorGridAlpha',.1,'XMinorGrid','off','YMinorGrid','off','Layer','top');grid(ax,'on');
end

function P=palette()
P=[0 114 178;213 94 0;0 158 115;204 121 167;102 102 102;230 159 0;86 180 233;34 34 34]/255;
end

function c=seriescolor(s,j,P)
c=P(mod(j-1,size(P,1))+1,:);names={'FIXED3D_WLS','GH_LOCAL','GH_MARGDIAG','GH_FULL'};
for k=1:4,if contains(s,names{k}),c=P(k,:);return;end,end
if contains(s,'Slope 1'),c=[.2 .2 .2];return;end
r=regexp(s,'(?:Geometry|Regime) (\d)','tokens','once');if ~isempty(r),c=P(str2double(r{1}),:);return;end
if startsWith(s,'Empirical rho')||startsWith(s,'Theory rho'),v=sscanf(s(regexp(s,'[^ ]+$','start'):end),'%f');ix=find(abs([0 .3 .6 .9]-v)<1e-9,1);if ~isempty(ix),c=P(ix,:);end
elseif startsWith(s,'Empirical a')||startsWith(s,'Theory a'),v=sscanf(s(regexp(s,'[^ ]+$','start'):end),'%f');ix=find(abs([.25 .5 .75]-v)<1e-9,1);if ~isempty(ix),c=P(ix,:);end,end
end

function s=cleanlabel(s)
s=char(string(s));from={'FIXED3D_WLS','GH_LOCAL','GH_MARGDIAG','GH_FULL','Full covariance','No-shared reference','linear_sampling','actual_fixed_sampling','blocks','FULL_correct','omit_global','omit_patch','MARGDIAG','LOCAL','FIXED3D','FULL','principal_point','log_f','kappa'};
to={'Fixed-3D','GH local','GH marginal','GH full','Full covariance','No-shared reference','Linear, fixed C','Nonlinear, fixed C','Nonlinear, fitted C','Correct full','Omit global','Omit patch','Marginal','Local','Fixed-3D','Full','Principal point','Log focal','Distortion'};
for k=1:numel(from),if strcmp(s,from{k}),s=to{k};return;end,end
if contains(s,'Slope 1'),s='Slope 1 reference';return;end
s=strrep(s,'Floor','Analytical limit');s=strrep(s,'0.02m','0.02 m');s=strrep(s,'0.10m','0.10 m');s=strrep(s,'Analytical shared floor','Analytical shared part');s=strrep(s,'+ focal (7)','+ f (7)');s=strrep(s,'+ principal point (10)','+ pp (10)');
for k=1:4,s=strrep(s,from{k},to{k});end
s=strrep(s,'Geometry ','G');s=strrep(s,'Regime ','R');s=strrep(s,' predicted',' (pred.)');s=strrep(s,'J04 ','');s=strrep(s,'_',' ');
end

function s=axislabel(s)
from={'Noise standard-deviation multiplier','Relative full depth width','relative_depth_spread','points_per_plane','independent_planes','global_datum_std','Mean coverage / cluster bootstrap CI','Full 10D coverage','Position coverage','10D coverage (narrow geometry)','Normalized remainder RMS','Nominal 95% coverage','Assumed method / covariance','Variance factor median / IQR','Global-test rejection rate','Mean variance factor (df=2)','Position variance contribution (m^2)','GH_FULL coverage'};
to={'Noise STD multiplier \epsilon','Relative depth width \delta_z','Relative depth width \delta_z','Points per plane','Independent planes','Global datum STD (m)','Mean full coverage','Full-camera (10-D) coverage','Position (3-D) coverage','Full-camera coverage, narrow geometry','Standardised remainder RMS','Coverage','Assumed covariance','Variance factor (median, IQR)','Residual-test rejection rate','Mean variance factor (df = 2)','Position variance contribution (m^2)','GH full coverage'};
s=char(string(s));for k=1:numel(from),if strcmp(s,from{k}),s=to{k};return;end,end
end

function L=labels(x)
L=cell(1,numel(x));for k=1:numel(x),if iscell(x),L{k}=cleanlabel(x{k});else,L{k}=cleanlabel(x(k));end,end
end

function a=item(s,i)
if iscell(s),a=s{i};else,a=s(i);end
end

function c=findcondition(a,suffix)
for k=1:numel(a),q=item(a,k);if endsWith(string(q.condition),suffix),c=q;return;end,end
error('prpaper:MissingCondition','Required condition %s is absent.',suffix);
end

function m=findmethod(a,label)
for k=1:numel(a),q=item(a,k);if strcmp(q.label,label),m=q;return;end,end
error('prpaper:MissingMethod','Required method %s is absent.',label);
end

function T=as_table(x)
if istable(x),T=x;return;end
if numel(x)>1,T=struct2table(x);return;end
% JSON-style structure of columns and native engine struct columns.
f=fieldnames(x);y=struct;
for k=1:numel(f),v=x.(f{k});if ischar(v),v={v};end;y.(f{k})=v(:);end
T=struct2table(y);
end

function C=normalcov(A,n)
A=double(A);if isequal(size(A),[10 10 n]),C=A;elseif isequal(size(A),[n 10 10]),C=permute(A,[2 3 1]);elseif n==1&&isequal(size(A),[10 10]),C=A;else,error('prpaper:CovarianceShape','Expected N-by-10-by-10 or 10-by-10-by-N covariance arrays.');end
end

function P=scaledinverse(C)
s=sqrt(diag(C));R=C./(s*s');P=(R\eye(size(R)))./(s*s');P=(P+P')/2;
end

function H=whiten(C)
[V,L]=eig((C+C')/2,'vector');[L,ix]=sort(L,'descend');V=V(:,ix);assert(all(L>0),'Display marginal covariance must be positive definite.');
if V(1,1)<0,V(:,1)=-V(:,1);end;if V(2,2)<0,V(:,2)=-V(:,2);end
H=diag(1./sqrt(L))*V';assert(norm(H*C*H'-eye(2),'fro')<1e-6,'Marginal whitening verification failed.');
end

function B=ellipse(C,q)
s=sqrt(diag(C));R=C./(s*s');R=(R+R')/2;L=chol(R,'lower');t=linspace(0,2*pi,1441);B=diag(s)*L*[cos(t);sin(t)]*sqrt(q);
end

function out=graphicsdata(f)
% Exact rendered geometry supports audit even when panel adapters change.
a=findall(f,'Type','axes');out=cell(1,numel(a));
for i=1:numel(a)
 ax=a(i);p=struct('xlim',ax.XLim,'ylim',ax.YLim,'xscale',ax.XScale,'yscale',ax.YScale,'xlabel',{ax.XLabel.String},'ylabel',{ax.YLabel.String},'title',{ax.Title.String},'objects',{{}});
 kids=ax.Children;
 for j=1:numel(kids)
  h=kids(j);r=struct('type',class(h));fields={'XData','YData','ZData','CData','SizeData','BinEdges','BinCounts','YNegativeDelta','YPositiveDelta','XNegativeDelta','XPositiveDelta','DisplayName','Value'};
  for k=1:numel(fields),name=fields{k};if isprop(h,name),v=h.(name);if isnumeric(v)||ischar(v)||isstring(v)||iscell(v),r.(name)=v;end,end,end
  p.objects{end+1}=r;
 end
 out{i}=p;
end
end
