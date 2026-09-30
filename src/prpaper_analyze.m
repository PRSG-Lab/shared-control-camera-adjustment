function analysis = prpaper_analyze(DATA,destination,opt)
%PRPAPER_ANALYZE MATLAB-only postprocessing of saved camera and target data.
% No fitting, random observations, or fitted-covariance rescaling is done here.
% Fixed-metric decompositions use population (1/N) centred scatter, whereas
% the original sample covariance summaries use their original 1/(N-1) rule.
if nargin<2,destination='';end
if nargin<3,opt=struct();end
if isstruct(destination),opt=destination;destination='';end
analysis.schema='pr-paper-analysis-1.0';
analysis.definition='All numerical results derive from DATA, without camera refitting.';
analysis.chart=chart_analysis(DATA.focal,opt);
analysis.targets=target_analysis(DATA.revision.postprocess);
analysis.bias=bias_analysis(DATA.revision.bias,DATA.revision.postprocess);
analysis.native=native_analysis(DATA,opt);
analysis.reduced=prpaper_reduced(DATA,opt);
analysis.validation=prpaper_analysis_selftest(DATA,analysis);
if ~isempty(destination)
    if ~isfolder(destination),mkdir(destination);end
    save(fullfile(destination,'analysis.mat'),'analysis','-v7.3');
end
end

function c=chart_analysis(A,opt)
c=A; E=double(A.error_log_truth_minus_fit); F=double(A.error_direct_truth_minus_fit);
if size(E,2)~=10,E=E';F=F';end
N=size(E,1);f0=double(A.f_true);C=double(A.C_reference);
CL=trial_first(A.covariance_log,N);CF=trial_first(A.covariance_direct,N);
assert(isequal(size(E),size(F))&&size(C,1)==10,'Camera array dimensions disagree');
fh=A.f_hat(:);assert(numel(fh)==N&&all(fh>0),'Invalid fitted focal lengths');
assert(max(abs(E(:,7)-log(f0./fh)))<1e-9,'Saved focal errors and cameras disagree');
assert(max(abs(F(:,7)-f0*(-expm1(-E(:,7)))))<1e-7,'Direct errors are not exact finite differences');
other=[1:6 8:10];assert(max(abs(E(:,other)-F(:,other)),[],'all')<1e-12);
J0=eye(10);J0(7,7)=f0;C0F=J0*C*J0';
wl=nan(N,1);wf=wl;err=zeros(N,1);Cr=zeros(10,10,N);Cfr=Cr;
TL=eye(10);TL(1:3,1:3)=A.R_true;TF=TL;TF(7,7)=1/f0;
for k=1:N
    L=squeeze(CL(k,:,:));D=squeeze(CF(k,:,:));j=ones(10,1);j(7)=fh(k);
    err(k)=norm(D-L.*(j*j'),'fro')/max(norm(D,'fro'),realmin);
    wl(k)=quadratic(E(k,:)',L);wf(k)=quadratic(F(k,:)',D);
    Cr(:,:,k)=TL*L*TL';Cfr(:,:,k)=TF*D*TF';
end
assert(max(err)<1e-10,'Full direct-focal covariance congruence failed');
if isfield(A,'W_log'),assert(max(abs(wl-A.W_log(:))./max(1,abs(wl)))<1e-7);end
if isfield(A,'W_direct'),assert(max(abs(wf-A.W_direct(:))./max(1,abs(wf)))<1e-7);end
c.W_log=wl;c.W_direct=wf;c.chi2_10_95=2*gammaincinv(.95,5);c.chi2_2_95=2*gammaincinv(.95,1);
c.inside_log=wl<=c.chi2_10_95;c.inside_direct=wf<=c.chi2_10_95;
c.N=N;c.n=N;c.error_log_truth_minus_fit=E;c.error_direct_truth_minus_fit=F;
c.covariance_log=CL;c.covariance_direct=CF;
cb=mean(Cr,3);cfb=mean(Cfr,3);J=[3 7];K=setdiff(1:10,J);
M=cb(J,J);S=M-cb(J,K)*(cb(K,K)\cb(K,J));S=(S+S')/2;
P=inverse_scaled(cb);S2=P(J,J)\eye(2);
c.Cbar_rotated=cb;c.M=M;c.M_direct=cfb(J,J);c.S=S;
c.H=principal_whitener(M);c.H_direct=principal_whitener(c.M_direct);
c.whitened_slice_covariance=c.H*S*c.H';
c.conditional_over_marginal_eigenvalues=sort(eig(c.whitened_slice_covariance));
c.slice_semiaxes=sqrt(c.chi2_10_95*c.conditional_over_marginal_eigenvalues);
c.schur_relative_error=norm(S-S2,'fro')/norm(S,'fro');
c.marginal_radius=sqrt(c.chi2_2_95);
% Rotate the position error into the true camera's optical coordinates.
d=E(:,1:3)*A.R_true(3,:)';c.optical_position_error=d;
c.uw_log=[d E(:,7)]*c.H';c.uw_direct=[d F(:,7)/f0]*c.H_direct';
c.x=d/sqrt(M(1,1));c.ylog=E(:,7)/sqrt(M(2,2));c.ydirect=(F(:,7)/f0)/sqrt(M(2,2));
c.regressions.log=regression(c.x,c.ylog);c.regressions.direct=regression(c.x,c.ydirect);
% Optional descriptive paired bootstrap. MATLAB's stream intentionally differs
% from the historical NumPy default_rng; analytical coefficients remain equal.
B=option(opt,'curvature_bootstrap',option(opt,'bootstrap_replicates',2000));
seed=option(opt,'curvature_seed',option(opt,'analysis_seed',9003));
rs=RandStream('mt19937ar','Seed',seed);boot=nan(B,2);
% Tiny smoke samples do not support a meaningful curvature bootstrap.
for b=1:B*(N>=10)
    ix=randi(rs,N,N,1);Q=[ones(N,1) c.x(ix) c.x(ix).^2];
    beta=Q\[c.ylog(ix) c.ydirect(ix)];boot(b,:)=beta(3,:);
end
c.curvature_bootstrap=struct('coefficients',boot,'seed',seed,'generator','mt19937ar',...
    'note','Paired descriptive bootstrap; differs from historical NumPy RNG; not a confidence-region test.');
for k=1:2
    names={'log','direct'};c.regressions.(names{k}).quadratic_coefficient_bootstrap_CI95=...
        [quantile_linear(boot(:,k),.025) quantile_linear(boot(:,k),.975)];
end
U=F;U(:,7)=U(:,7)/f0;D=U-E;
[sL,Z]=fixed_stats(E,C);[sF,ZF]=fixed_stats(F,C0F); %#ok<ASGLU>
sd=sqrt(diag(C));L=chol(C./(sd*sd'),'lower');ZD=(L\(D./sd')')';
Zc=Z-mean(Z,1);Dc=ZD-mean(ZD,1);
delta=sum(Dc.^2,'all')/N;cross=2*sum(Zc.*Dc,'all')/N;
c.fixed_metrics=struct('log',sL,'direct',sF,'direct_truth_reference',sF,...
    'delta_variance_term',delta,'twice_cross_term',cross,...
    'linear_centred_expectation',10*(1-1/N),...
    'decomposition_closure_absolute_error',abs(sL.centered_scatter_nees+delta+cross-sF.centered_scatter_nees),...
    'C_reference_direct',C0F,'J_truth',J0,'delta_common_tangent',D);
il=c.inside_log;idf=c.inside_direct;
c.paired_counts=struct('both',nnz(il&idf),'direct_only',nnz(~il&idf),...
    'log_only',nnz(il&~idf),'neither',nnz(~il&~idf));
c.coverage=struct('log',mean(il),'direct',mean(idf),'log_wilson',wilson(nnz(il),N),...
    'direct_wilson',wilson(nnz(idf),N));
c.display=struct('axis_limit',4.7,'clip_trials_log',find(any(abs(c.uw_log)>4.7,2)),...
    'clip_trials_direct',find(any(abs(c.uw_direct)>4.7,2)),...
    'within_2D_log',nnz(sum(c.uw_log.^2,2)<=c.chi2_2_95),...
    'within_2D_direct',nnz(sum(c.uw_direct.^2,2)<=c.chi2_2_95),...
    'failed_10D_inside_2D_log',nnz(~il&sum(c.uw_log.^2,2)<=c.chi2_2_95),...
    'median_absolute_optical_error_m',median(abs(d)),...
    'median_absolute_focal_error_px',median(abs(F(:,7))),...
    'focal_error_quartiles_px',arrayfun(@(q)quantile_linear(F(:,7),q),[.25 .5 .75]));
Sm=zeros(2);
for k=1:N,Q=Cr(:,:,k);Sm=Sm+Q(J,J)-Q(J,K)*(Q(K,K)\Q(K,J));end
c.mean_trial_schur_covariance=Sm/N;
c.mean_trial_schur_relative_difference=norm(Sm/N-S,'fro')/norm(S,'fro');
P0=inverse_scaled(C);c.position_precision_trace_ratio=trace(P0(1:3,1:3))/trace(inverse_scaled(C(1:3,1:3)));
c.display_plane_precision_trace_ratio=trace(inverse_scaled(S))/trace(inverse_scaled(M));
c.full_covariance_congruence_relative_error=max(err);
end

function out=target_analysis(pr)
rows={};agg={};variance={};
for k=1:numel(pr.target_conditions)
    q=item(pr.target_conditions,k);
    for t=1:numel(q.targets)
        a=item(q.targets,t);des=a.design;
        for kind={'plane','image'}
            name=kind{1};v=a.(name);np=size(v.coverage,1);
            for m=1:numel(q.methods)
                label=char(string(item(q.methods,m)));pred=nan(np,1);emp=pred;
                for j=1:np
                    pred(j)=trace(v.predicted_covariance(:,:,j,m));
                    emp(j)=trace(v.empirical_covariance(:,:,j,m));
                    rows{end+1}=struct('condition',q.condition,'target',des.id,'kind',name,'method',label,...
                        'point',j,'depth_m',des.depth,'tilt_deg',des.tilt_deg,...
                        'rmse',v.rmse(j,m),'coverage',v.coverage(j,m),...
                        'coverage_operational',v.coverage_operational(j,m),...
                        'n_total',q.n_total,'n_error_valid',v.error_valid_count(j,m),...
                        'n_covariance_valid',v.valid_count(j,m),'predicted_trace',pred(j),'empirical_trace',emp(j)); %#ok<AGROW>
                end
                agg{end+1}=struct('condition',q.condition,'target',des.id,'kind',name,'method',label,...
                    'depth_m',des.depth,'tilt_deg',des.tilt_deg,'points',np,...
                    'rmse_min',min(v.rmse(:,m),[],'omitnan'),'rmse_max',max(v.rmse(:,m),[],'omitnan'),...
                    'coverage_min',min(v.coverage(:,m),[],'omitnan'),'coverage_max',max(v.coverage(:,m),[],'omitnan'),...
                    'operational_min',min(v.coverage_operational(:,m),[],'omitnan'),...
                    'operational_max',max(v.coverage_operational(:,m),[],'omitnan')); %#ok<AGROW>
                variance{end+1}=struct('condition',q.condition,'target',des.id,'kind',name,'method',label,...
                    'depth_m',des.depth,'tilt_deg',des.tilt_deg,...
                    'median_predicted_trace',median(pred,'omitnan'),...
                    'median_empirical_trace',median(emp,'omitnan'),...
                    'median_empirical_predicted_trace_ratio',median(emp./pred,'omitnan'),...
                    'median_predicted_scatter',median(sqrt(pred),'omitnan')); %#ok<AGROW>
            end
        end
    end
end
out=struct('pointwise',struct2table([rows{:}]),'aggregate',struct2table([agg{:}]),...
    'variance',struct2table([variance{:}]),...
    'definition','Medians/ranges across the same pointwise target grid; covariance and RMSE retain source valid-count conditioning.');
end

function out=bias_analysis(bias,pr)
rows={};details={};
for k=1:numel(bias.geometries)
    g=item(bias.geometries,k);di=[];
    for i=1:numel(pr.diagnostics)
        z=item(pr.diagnostics,i);
        if isfield(z.spec,'geometry_id')&&z.spec.geometry_id==g.geometry_id&&z.spec.noise_scale==1,di=z;break;end
    end
    if isempty(di),continue;end
    q=find_method(di.methods,'GH_FULL');C=q.reference_reported_covariance;
    bb=g.b2(:,end);cc=[];mx=0;
    for i=1:numel(g.comparison)
        v=item(g.comparison,i);pb=v.predicted_bias(:,end);eb=v.empirical_bias(:);
        se=v.standard_error(:);z=(pb-eb)./se;
        if any(~isfinite(z)),mx=NaN;elseif isfinite(mx),mx=max(mx,max(abs(z)));end
        details{end+1}=struct('geometry',g.geometry_id,'epsilon',v.epsilon,...
            'source_condition',v.source_condition,'predicted_bias',pb,'empirical_bias',eb,...
            'component_SE_residual',z,'max_component_SE_residual',max(abs(z))); %#ok<AGROW>
        if v.epsilon==1,cc=v;end
    end
    assert(~isempty(cc),'Unit-noise bias comparison is missing');
    wb=nan(1,size(C,1));we=wb;
    if all(isfinite(bb)),[~,wb]=fixed_stats(bb',C);end
    if all(isfinite(cc.empirical_bias)),[~,we]=fixed_stats(cc.empirical_bias(:)',C);end
    rows{end+1}=struct('Geometry',g.geometry_id,'Directions',g.directions_used,...
        'Finest_relative_change',g.step_relative_change(end),...
        'Predicted_squared_norm',sum(wb.^2),'Empirical_squared_norm',sum(we.^2),...
        'Max_component_SE_residual',mx,'Whitened_direction_cosine',dot(wb,we)/norm(wb)/norm(we),...
        'Complete_trace',all(g.complete_trace),'All_directional_fits_valid',all(g.valid(:))); %#ok<AGROW>
end
out=struct('summary',struct2table([rows{:}]),'details',{details});
end

function out=native_analysis(DATA,opt)
out=DATA.native;records=out.records;
for i=1:numel(records)
    r=item(records,i);N=numel(r.trial_ids);r.W_log=nan(1,N);r.W_direct=nan(1,N);
    r.covariance_valid=false(1,N);r.congruence_discrepancy=nan(1,N);
    for k=1:N
        if ~r.fit_valid(k),continue;end
        e=r.error_log(:,k);C=r.covariance_log(:,:,k);fh=r.f_hat(k);
        [wl,ol]=prnc.Stats.quadratic(e,C);J=ones(10,1);J(7)=fh;
        ef=e;ef(7)=fh-r.f_true;[wf,of]=prnc.Stats.quadratic(ef,C.*(J*J'));
        ee=e;ee(7)=-expm1(-e(7));[wc,oc]=prnc.Stats.quadratic(ee,C);
        if ~(ol&&of&&oc),continue;end
        r.W_log(k)=wl;r.W_direct(k)=wf;r.covariance_valid(k)=true;
        r.congruence_discrepancy(k)=abs(wc-wf)/max(1,abs(wf));
    end
    threshold=2*gammaincinv(.95,5);
    r.covered_log=r.covariance_valid&r.W_log<=threshold;
    r.covered_direct=r.covariance_valid&r.W_direct<=threshold;
    r.summary=prnc.Stats.summary(r);records{i}=r;
end
out.records=records;out.condition_summary=prnc.Reports.condition_table(records);
out.table4=prnc.Reports.table4(records,struct('results',DATA.revision.postprocess));
profile='paper';if isfield(DATA.base.config,'profile'),profile=DATA.base.config.profile;end
if isfield(opt,'profile')&&strcmp(opt.profile,'smoke'),profile='smoke';end
[out.table5,out.population]=prnc.Reports.population(records,DATA.base,struct('profile',profile));
end

function [r,Z]=fixed_stats(E,C)
sd=sqrt(diag(C));R=C./(sd*sd');L=chol((R+R')/2,'lower');
Z=(L\(E./sd')')';N=size(E,1);mu=mean(Z,1);Zc=Z-mu;
emp=(E-mean(E,1))'*(E-mean(E,1))/N;Rinv=L'\(L\eye(size(C)));
r=struct('mean_nees',sum(Z.^2,'all')/N,'bias_nees',sum(mu.^2),...
    'centered_scatter_nees',sum(Zc.^2,'all')/N,...
    'covariance_trace_nees',trace(Rinv*(emp./(sd*sd'))),'rank_C',rank(R));
assert(abs(r.mean_nees-r.bias_nees-r.centered_scatter_nees)<1e-7*max(1,r.mean_nees));
assert(abs(r.centered_scatter_nees-r.covariance_trace_nees)<1e-7*max(1,r.mean_nees));
end
function P=inverse_scaled(C)
sd=sqrt(diag(C));R=C./(sd*sd');L=chol((R+R')/2,'lower');P=(L'\(L\eye(size(C))))./(sd*sd');
end
function w=quadratic(e,C)
sd=sqrt(diag(C));R=C./(sd*sd');L=chol((R+R')/2,'lower');w=sum((L\(e./sd)).^2);
end
function H=principal_whitener(C)
[V,D]=eig((C+C')/2);[ev,ix]=sort(diag(D),'descend');V=V(:,ix);
if V(1,1)<0,V(:,1)=-V(:,1);end
if V(2,2)<0,V(:,2)=-V(:,2);end
H=diag(1./sqrt(ev))*V';assert(norm(H*C*H'-eye(2),'fro')<1e-8);
end
function r=regression(x,y)
if numel(x)<3||numel(unique(x))<3
    r=struct('linear_coefficients',nan(2,1),'quadratic_coefficients',nan(3,1),...
        'linear_rmse',NaN,'quadratic_rmse',NaN,'linear_r2',NaN,'quadratic_r2',NaN,'correlation',NaN);return;
end
Q1=[ones(size(x)) x];Q2=[Q1 x.^2];b1=Q1\y;b2=Q2\y;e1=y-Q1*b1;e2=y-Q2*b2;
den=sum((y-mean(y)).^2);cc=corrcoef(x,y);
r=struct('linear_coefficients',b1,'quadratic_coefficients',b2,'linear_rmse',sqrt(mean(e1.^2)),...
    'quadratic_rmse',sqrt(mean(e2.^2)),'linear_r2',1-sum(e1.^2)/den,...
    'quadratic_r2',1-sum(e2.^2)/den,'correlation',cc(1,2));
end
function C=trial_first(C,N)
if isequal(size(C),[10 10 N]),C=permute(C,[3 1 2]);end
assert(isequal(size(C),[N 10 10]),'Expected N-by-10-by-10 focal covariance');
end
function a=item(v,i)
if iscell(v),a=v{i};else,a=v(i);end
end
function a=find_method(v,label)
a=[];for i=1:numel(v),q=item(v,i);if strcmp(q.label,label),a=q;return;end,end
assert(~isempty(a),'Method not found: %s',label);
end
function x=option(opt,key,default)
if isfield(opt,key),x=opt.(key);else,x=default;end
end
function q=quantile_linear(v,p)
v=sort(v(isfinite(v)));if isempty(v),q=NaN;return;end
t=1+(numel(v)-1)*p;lo=floor(t);hi=ceil(t);q=v(lo)+(t-lo)*(v(hi)-v(lo));
end
function ci=wilson(k,n)
z=1.959963984540054;p=k/n;d=1+z*z/n;mid=(p+z*z/(2*n))/d;
h=z*sqrt(p*(1-p)/n+z*z/(4*n*n))/d;ci=[mid-h mid+h];
end
