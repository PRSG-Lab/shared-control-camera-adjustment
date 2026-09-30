function report=prpaper_analysis_selftest(DATA,A)
%PRPAPER_ANALYSIS_SELFTEST Identities and optional frozen reference assertions.
% Reference numbers are assertions only: they never populate result tables.
c=A.chart;N=c.N;p=c.paired_counts;
assert(p.both+p.log_only+p.direct_only+p.neither==N,'Paired counts do not close');
assert(p.both+p.log_only==nnz(c.inside_log));
assert(p.both+p.direct_only==nnz(c.inside_direct));
assert(c.schur_relative_error<1e-6,'Precision-block and Schur-slice construction disagree');
assert(c.full_covariance_congruence_relative_error<1e-10);
assert(c.fixed_metrics.decomposition_closure_absolute_error<1e-7);
assert(all(c.conditional_over_marginal_eigenvalues>0)&&all(c.conditional_over_marginal_eigenvalues<=1+1e-7));
assert(abs(c.fixed_metrics.log.centered_scatter_nees-c.fixed_metrics.log.covariance_trace_nees)<1e-7);
assert(abs(c.fixed_metrics.direct.centered_scatter_nees-c.fixed_metrics.direct.covariance_trace_nees)<1e-7);
reference=false;
% Restrict published-value checks to the archived source run, never new runs.
if isfield(DATA,'provenance')&&isfield(DATA.provenance,'reference_fixture')
    reference=logical(DATA.provenance.reference_fixture);
elseif isfield(DATA.base,'meta')&&isfield(DATA.base.meta,'run_id')
    reference=strcmp(DATA.base.meta.run_id,'run_c2835a74eff3')&&N==2000;
end
if reference
    assert(isequal([p.both p.direct_only p.log_only p.neither],[984 677 4 335]));
    assert(abs(c.coverage.log-.494)<1e-12&&abs(c.coverage.direct-.8305)<1e-12);
    assert(abs(c.fixed_metrics.log.centered_scatter_nees-118.24)<.01);
    assert(abs(c.fixed_metrics.direct.centered_scatter_nees-14.12)<.01);
    v=A.targets.variance;ix=endsWith(string(v.condition),'J09c012')&strcmp(v.kind,'plane')&strcmp(v.method,'GH_LOCAL')&v.tilt_deg==0;
    w=sortrows(v(ix,:),'depth_m');
    assert(height(w)==3&&max(abs(w.median_predicted_trace-[.00303197;.00003921;.01145400]))<1e-8);
    assert(max(abs(w.median_empirical_predicted_trace_ratio-[2.8453;145.5669;1.4996]))<1e-4);
end
report=struct('passed',true,'reference_value_assertions_applied',reference,...
    'paired_counts_closed',true,'full_covariance_congruence',true,...
    'schur_precision_identity',true,'fixed_metric_trace_identity',true,...
    'finite_focal_error_identity',true,'target_covariances_reaggregated',true,...
    'scope','Tests validate stored-data postprocessing; they do not certify a newly unexecuted simulation.');
end
