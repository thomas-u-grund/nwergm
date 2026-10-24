# What is validated against the R reference

Each line: feature | status | syntax | validation (taken from the development logs at the time of the split).

* missing dyads (NA ties), dyad-independent models | done | automatic: NA cells of the network matrix (off-diagonal) are detected; e(nmissing) | MPLE coef/SE/logLik/N equal R (3-NA 30-node undirected: |diff|<1e-6; 70-NA 40-node: 1e-6). Missing dyads leave the pseudolikelihood (e(N)=informative dyads), as R (MPLE=MLE).
* missing dyads, dyad-dependent MCMLE | done | automatic | Handcock-Gile two-sample estimator: constrained sample (only missing dyads free, masked TNT, native), estimating eq. mean(unconstrained)-mean(constrained), information = V-Vobs (PSD-fixed), final vcov with MC error of both samples. Undirected edges+nodematch+triangle (70 NA) and directed edges+mutual (60 NA): estimates, SE, logLik within R's own seed-to-seed spread.
* missing dyads, dyad-dependent MPLE | done | method(mple) | starting network gets round(density*nNA) missing dyads imputed at random (R single.impute.dyads); result depends on seed as in R.
* missing nodal covariates | R errors -> same | any attribute term | error rc 416 "Attribute has missing data, which is not currently supported by ergm" (R text). Two-mode terms check only own-mode attribute (R trims first).
* missing values in edgecov/hamming networks | R fails with a cryptic error (MPLE, NA in dyadic covariate) -> clean error rc 416 | edgecov(), hamming() |
* combination with freedyads/blockdiag/fixdensity | not done | error 198 | obs-process with extra constraints not implemented
* e(ll), e(df_m), e(N), e(aic), e(bic), e(deviance), e(ll_0) | done | all fits; nologlik skips bridge | dyad-independent exact: equal to R logLik/AIC/BIC/null to 1e-7; dd MPLE pseudo-ll equal R (|diff| 1e-4); MCMLE bridge sampling (dyad-independent-start, R ergm.bridge.dindstart.llk, 16 bridges, midpoint path) within R's MC spread (-190.21 vs R -190.21, NA case -189.70..-189.71 vs R -189.70..-189.72). Options bridgesteps(), bridgesamplesize(), bridgeinterval().
* estat ic | done | estat ic | shows N, ll(null), ll(model), df, AIC, BIC; refuses when e(ll) missing
* lrtest | verified | lrtest m0 m1 | chi2 3.12 p .2101 = R anova
* predict | done | predict, matrix(m)|frame(f) [pr|xb] | equals R predict.ergm (conditional probs, link) to 1e-7. Note: R uses the last MCMC network (newnetwork) as basis for dyad-dependent MCMLE fits; nwergm always uses the observed network.
* curved MCMLE logLik | not done | | e(ll) missing (curved model: no bridge implemented); curved MPLE ll works
* # INVENTORY_UPDATES (agent E3, structural non-bipartite terms).  Format: term | status | nwergm syntax | validation
* # Branch ergmE3.  All terms are entered through the NEW option structural(termlist) of nwergm (and nwergm simulate); arguments have R names/defaults, node attributes are numeric variables.
* # Validation: R ergm 4.12.0.  Statistic = summary(); MPLE = ergm(estimate="MPLE") coefficients/SE on 4-8 networks (random n=16..100 + florentine marriage, sampson samplk1);
* #   a fit that R itself reports as separated/collinear (|coef| Inf/NA or SE > 20) is not comparable and was skipped (counted as "degenerate in R" in dev/E3/table_terms.csv).
* #   Tolerance used: statistic 1e-6 (float arithmetic of tripercent), MPLE coef 1e-4 (density/meandeg relative to |coef|), SE 1e-3 relative.
* density | IMPLEMENTED | structural(density (both; edges may be omitted)) | summary() max |diff| 5e-16 on 8 nets; MPLE coef diff 3e-09, SE diff 7e-05 (8 nets)
* meandeg | IMPLEMENTED | structural(meandeg (both; edges may be omitted)) | summary() max |diff| 4e-15 on 8 nets; MPLE coef diff 3e-09, SE diff 7e-05 (8 nets)
* twopath | IMPLEMENTED | structural(twopath) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 2e-07, SE diff 1e-05 (8 nets)
* isolates | IMPLEMENTED | structural(isolates) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 6e-06, SE diff 6e-05 (4 nets)
* isolatededges | IMPLEMENTED | structural(isolatededges) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-10, SE diff 1e-08 (1 nets)
* degree1.5 | IMPLEMENTED | structural(degree1.5) | summary() max |diff| 5e-12 on 4 nets; MPLE coef diff 9e-08, SE diff 4e-05 (4 nets)
* odegree1.5 | IMPLEMENTED | structural(odegree1.5) | summary() max |diff| 5e-13 on 4 nets; MPLE coef diff 3e-08, SE diff 2e-05 (3 nets)
* idegree1.5 | IMPLEMENTED | structural(idegree1.5) | summary() max |diff| 3e-13 on 4 nets; MPLE coef diff 6e-08, SE diff 3e-05 (4 nets)
* degcrossprod | IMPLEMENTED | structural(degcrossprod) | summary() max |diff| 6e-14 on 4 nets; MPLE coef diff 6e-09, SE diff 7e-06 (4 nets)
* degcor | IMPLEMENTED | structural(degcor) | summary() max |diff| 3e-16 on 4 nets; MPLE coef diff 5e-08, SE diff 7e-06 (4 nets)
* m2star | IMPLEMENTED | structural(m2star) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-09, SE diff 6e-07 (4 nets)
* concurrentties | IMPLEMENTED | structural(concurrentties) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 9e-07, SE diff 6e-05 (3 nets)
* concurrentties(by) | IMPLEMENTED | structural(concurrentties(by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 9e-07, SE diff 5e-04 (3 nets)
* concurrent(by) | IMPLEMENTED | structural(concurrent(by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-09, SE diff 6e-07 (2 nets)
* altkstar | IMPLEMENTED | structural(altkstar(lambda=# fixed)) | summary() max |diff| 5e-13 on 4 nets; MPLE coef diff 8e-08, SE diff 2e-05 (4 nets)
* asymmetric | IMPLEMENTED | structural(asymmetric) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 9e-07, SE diff 3e-06 (4 nets)
* asymmetric(attr) | IMPLEMENTED | structural(asymmetric(attr=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-08, SE diff 1e-05 (4 nets)
* asymmetric(diff) | IMPLEMENTED | structural(asymmetric(attr=a diff)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-07, SE diff 9e-05 (4 nets)
* mutual(same) | IMPLEMENTED | structural(mutual(same=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-05, SE diff 7e-06 (4 nets)
* mutual(same,diff) | IMPLEMENTED | structural(mutual(same=a diff)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 5e-11, SE diff 4e-07 (1 nets)
* mutual(by) | IMPLEMENTED | structural(mutual(by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-08, SE diff 1e-05 (3 nets)
* transitive | IMPLEMENTED | structural(transitive) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-07, SE diff 9e-06 (4 nets)
* intransitive | IMPLEMENTED | structural(intransitive) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-09, SE diff 9e-06 (4 nets)
* cycle | IMPLEMENTED | structural(cycle(k=3 4 5)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 4e-07, SE diff 2e-05 (6 nets)
* cycle (directed k=2) | IMPLEMENTED | structural(cycle(k=2 3)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 5e-08, SE diff 2e-05 (4 nets)
* cycle(semi) | IMPLEMENTED | structural(cycle(k=3 4 semi)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 5e-09, SE diff 5e-06 (4 nets)
* ttriple | IMPLEMENTED | structural(ttriple) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-07, SE diff 9e-06 (4 nets)
* ttriple(attr) | IMPLEMENTED | structural(ttriple(attr=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-08, SE diff 4e-06 (4 nets)
* ttriple(diff) | IMPLEMENTED | structural(ttriple(attr=a diff)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 3e-15, SE diff 1e-08 (1 nets)
* ctriple | IMPLEMENTED | structural(ctriple (R semantics, attr/diff added)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 3e-09, SE diff 2e-05 (4 nets)
* ctriple(attr) | IMPLEMENTED | structural(ctriple(attr=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-08, SE diff 1e-05 (3 nets)
* ctriple(diff) | IMPLEMENTED | structural(ctriple(attr=a diff)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-10, SE diff 5e-08 (1 nets)
* triangle | IMPLEMENTED | structural(triangle (undirected AND directed, as R)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 2e-06, SE diff 1e-05 (7 nets)
* triangle(attr) | IMPLEMENTED | structural(triangle(attr=a)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 2e-08, SE diff 9e-06 (6 nets)
* triangle(diff) | IMPLEMENTED | structural(triangle(attr=a diff)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 2e-06, SE diff 2e-06 (2 nets)
* tripercent | IMPLEMENTED | structural(tripercent) | summary() max |diff| 4e-14 on 4 nets; MPLE coef diff 4e-09, SE diff 1e-06 (3 nets)
* tripercent(attr) | IMPLEMENTED | structural(tripercent(attr=a)) | summary() max |diff| 2e-07 on 4 nets; MPLE coef diff 2e-08, SE diff 2e-05 (2 nets)
* tripercent(diff) | IMPLEMENTED | structural(tripercent(attr=a diff)) | summary() max |diff| 4e-14 on 4 nets; MPLE coef diff 2e-08, SE diff 3e-05 (1 nets)
* opentriad | IMPLEMENTED | structural(opentriad) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e+00, SE diff 1e-01 (1 nets)
* threetrail | IMPLEMENTED | structural(threetrail (4 types for directed)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 7e-08, SE diff 7e-05 (8 nets)
* nearsimmelian | IMPLEMENTED | structural(nearsimmelian) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-11, SE diff 1e-08 (2 nets)
* simmelian | IMPLEMENTED | structural(simmelian) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 5e-09, SE diff 3e-06 (1 nets)
* simmelianties | IMPLEMENTED | structural(simmelianties) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-08, SE diff 6e-06 (1 nets)
* triadcensus | IMPLEMENTED | structural(triadcensus(levels)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 1e-07, SE diff 4e-05 (3 nets)
* nsp | IMPLEMENTED | structural(nsp(d, type=)) | summary() max |diff| 0e+00 on 8 nets; MPLE coef diff 3e-06, SE diff 1e-05 (5 nets)
* degree(d) plain | IMPLEMENTED | structural(degree(d=...)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 7e-06, SE diff 1e-03 (3 nets)
* degree(by) | IMPLEMENTED | structural(degree(d=.. by=a)) | summary() max |diff| 0e+00 on 3 nets; MPLE coef diff 7e-09, SE diff 5e-05 (2 nets)
* degree(homophily) | IMPLEMENTED | structural(degree(d=.. by=a homophily)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-07, SE diff 4e-05 (4 nets)
* odegree(d) | IMPLEMENTED | structural(odegree(d=...)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-07, SE diff 1e-04 (2 nets)
* odegree(by) | IMPLEMENTED | structural(odegree(d=.. by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-08, SE diff 1e-05 (1 nets)
* odegree(homophily) | IMPLEMENTED | structural(odegree(d=.. by=a homophily)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-07, SE diff 2e-05 (4 nets)
* idegree(d) | IMPLEMENTED | structural(idegree(d=...)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 9e-08, SE diff 5e-05 (2 nets)
* idegree(by) | IMPLEMENTED | structural(idegree(d=.. by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-08, SE diff 2e-05 (1 nets)
* idegree(homophily) | IMPLEMENTED | structural(idegree(d=.. by=a homophily)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-07, SE diff 8e-05 (4 nets)
* degrange | IMPLEMENTED | structural(degrange(from= to=)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-08, SE diff 4e-05 (4 nets)
* degrange(vector,Inf) | IMPLEMENTED | structural(degrange(from=0 3 to=2 Inf)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-05, SE diff 2e-04 (4 nets)
* degrange(by) | IMPLEMENTED | structural(degrange(.. by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-09, SE diff 6e-06 (3 nets)
* degrange(homophily) | IMPLEMENTED | structural(degrange(.. by=a homophily)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 8e-08, SE diff 9e-06 (4 nets)
* odegrange | IMPLEMENTED | structural(odegrange(from= to=)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-07, SE diff 1e-05 (3 nets)
* odegrange(by) | IMPLEMENTED | structural(odegrange(.. by=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 3e-07, SE diff 1e-05 (2 nets)
* idegrange(homophily) | IMPLEMENTED | structural(idegrange(.. by=a homophily)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 1e-08, SE diff 9e-06 (4 nets)
* kstar | IMPLEMENTED | structural(kstar(k=..)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 2e-07, SE diff 6e-05 (4 nets)
* kstar(attr) | IMPLEMENTED | structural(kstar(k=.. attr=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 4e-07, SE diff 2e-05 (4 nets)
* ostar(attr) | IMPLEMENTED | structural(ostar(k=.. attr=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 9e-07, SE diff 3e-05 (3 nets)
* istar(attr) | IMPLEMENTED | structural(istar(k=.. attr=a)) | summary() max |diff| 0e+00 on 4 nets; MPLE coef diff 6e-06, SE diff 2e-05 (4 nets)
* localtriangle | IMPLEMENTED | structural(localtriangle(x=netname)) | summary() equal on 2 networks (undirected 3 triangles / directed 18, plus the 14- and 12-node ones in cscripts/test_nwergm_structural.do)
* # MCMLE (dyad-dependent terms, R run 3 seeds vs nwergm 3 seeds, networks simulated from known models; dev/E3/ref_mcmle.R, run_mcmle.do, cmp_mcmle.R):
* #   M1 degree1.5; M2 altkstar(0.8 fixed)+triangle; M3 cycle(4)+triangle; M4 transitive; M5 m2star+cycle(3); M6 ttriple+odegree1.5 -> every coefficient within 0.1 posterior SE of R and
* #   inside the R/Stata run-to-run Monte-Carlo spread (largest difference 0.077 = 0.07 SE for ttriple in M6).
* # Internal consistency (cscripts/test_nwergm_structural.do part 3): native change statistic of every dyad == stat(dyad=1)-stat(dyad=0) from the observed-statistic routine, 3 random graphs x 3 models, max diff < 1e-9
* #   (all terms except degcor and tripercent, whose R change statistic is not the difference of the summary statistic).
* # NOT DONE / not doable
* altkstar (curved, fixed=FALSE) | NOT IMPLEMENTED | - | R 4.12.0 itself cannot fit it in the test networks: ergm(net ~ edges + altkstar, estimate="MPLE") fails with "objfun returned gradient not having all elements finite" (und_c, simulated nets) or returns altkstar=0, altkstar.lambda=0 with a "linear dependence 8e+50 * edges = altkstar" warning (und_a, und_b), so there is nothing to compare with; fixed=TRUE is implemented and validated.
* coincidence, b1*/b2* terms, gwb1dsp/gwb2dsp, b1twostar, b1starmix | not mine | bipartite (agent E5)
* sociality | not mine | nodal covariate (agent E4)
* balance | NOT PLANNED (signed networks)
* levels= argument (all terms taking attr/by), keep= of asymmetric/mutual/threetrail(keep is implemented for threetrail only) | not implemented: all attribute levels are used; keep is accepted only by threetrail
* cyclicalties/transitiveties attr=, hamming cov=/attrname=, gwdegree attr=: untouched (other categories)
* # QUIRKS / GOTCHAS
* opentriad: in ergm 4.12.0 c_opentriad stores the 2-star part of the change in an unsigned `Edge` and negates it when a tie is removed (`-change` on unsigned = ~4.29e9 - change).  summary() is right (only additions),
* but every MPLE design row of a tied dyad and every MCMC proposal that removes a tie is garbage (ergmMPLE() shows min -4.3e9; the MPLE coefficient of opentriad comes out 0 with SE ~1e-7).  nwergm uses the correct change statistic, so its MPLE/MCMLE differ from R 4.12.0 for this term (statistic equal).
* triangle on a directed network (R cpp_changestats.cpp): neighbors(head) visits a node that is both in- and out-neighbour twice, and the change adds nw(k,tail)+nw(tail,k): copied exactly (statistic and MPLE equal R).
* degcrossprod/degcor: scaled with quantities of the OBSERVED network at model creation (2*edges; observed degree variance): copied; hence not available in `nwergm simulate` (error message). degcor: summary statistic is the true degree correlation, the change statistic is R's approximation (copied).
* tripercent: R uses float (single precision) ratios in the change statistic: copied with float casts; observed statistic is the sum of single-step changes along a build-up like R's (equal to R to 2e-7).
* Stata: coefficient names use "_" instead of R's "." (matrix column names such as triangle.a are read as time-series operators), "+" -> "plus" (deg3plus); directed nsp is named nsp_OTP0 ...
* Stata: `inlist()` accepts at most 9 string arguments (r(130) "expression too long"); tempnames in different ado programs can coincide and overwrite Mata globals: structural terms use fixed names __nwst_td<k>.
* findfile() finds the stale ergm_mcmc plugin in the user's PLUS folder before the repo copy: test runs need `adopath ++ "lib/plugins/macos"` (done in cscripts/test_nwergm_structural.do for all three platforms).
* Observed statistics of structural terms are obtained by the native plugin (new mode 3: empty the graph, add the ties one by one, sum the change statistics, plus the empty-network value), exactly how R's summary() works for terms without an s_ function.
* term | status | nwergm syntax | validation (what, max difference)
* Validation set: 3 bipartite networks (A 12x10, B 8x15, C 20x6 with hubs and 2 isolated mode-1 nodes), dev/bip_gen.R; R ergm 4.12.0.
* (a) observed statistic == summary(), (b) change statistics == R ergmMPLE() design matrix over ALL dyads (sorted, 1e-6), (c) MPLE coefficients/SE vs ergm(estimate="MPLE")
* where R's fit is well identified, (d) MCMLE on a 30x25 network (50 ties), R 4 seeds vs nwergm 3 seeds. Files: dev/bip_spec*.txt, dev/bip_ref.R, dev/bip_run.do, cscripts/test_nwergm_bip.do (206 cases, passes).
* b1concurrent | IMPLEMENTED | bconcurrent1(all) / bconcurrent1(by(var) levels(numlist)) | stat+design exact on A,B,C; MPLE <1e-6; MCMLE 0.02 SE
* b2concurrent | IMPLEMENTED | bconcurrent2(all) / bconcurrent2(by(var)) | same
* b1mindegree, b2mindegree | IMPLEMENTED | bmindegree1(numlist), bmindegree2(numlist) | same (d=0 included, as R's emptynwstats)
* b1degrange, b2degrange | IMPLEMENTED | bdegrange1(from, to(numlist) by(var) levels() homophily), bdegrange2 | same; to=. is Inf
* b1degree, b2degree by= / levels= / homophily= | IMPLEMENTED | bdegree1(numlist, by(var) levels() homophily) | same; plain bdegree1(numlist) unchanged; ranges such as bdegree1(0/3) now expand (also degree, kstar, ... : numlist ranges)
* b1star, b2star attr=/levels= | IMPLEMENTED | bstar1(k, attr(var) levels()) | same; copies R quirk: values outside levels= are all recoded to one extra "other" value that matches itself (R 4.12.0 b1star(2,attr=,levels=1) counts stars among the other values)
* b1covrange, b2covrange | IMPLEMENTED | bcovrange1(var), bcovrange2(var) | same (x is a float in Stata: stat diff 2e-5)
* b1factordistinct, b2factordistinct | IMPLEMENTED | bfactordistinct1(var, levels()) | same
* b1sociality, b2sociality | IMPLEMENTED | bsociality1(numlist) e.g. bsociality1(-1) (R default nodes=-1), bsociality2 | same; numeric nodes= are POSITIONS within the mode (R: levels spec), not node ids
* b1starmix, b2starmix | IMPLEMENTED | bstarmix1(k, attr(var) nodiff base(numlist)) | same (diff=TRUE/FALSE, base=)
* b1twostar, b2twostar | IMPLEMENTED | btwostar1(var, attr2(var) levels1() levels2() levels3() base()) | same
* coincidence | IMPLEMENTED | coincidence(all), coincidence(active(#)) | same on B,C; on A the 45-parameter MPLE is quasi-separated (logit does not converge, R returns a fit)
* b1dsp, b2dsp | IMPLEMENTED | bdsp1(numlist), bdsp2 | same (d=0 counts all pairs of the mode)
* gwb1dsp, gwb2dsp fixed=TRUE | IMPLEMENTED | bgwdsp1(decay), bgwdsp2(decay) | same
* gwb1dsp, gwb2dsp, gwb1degree, gwb2degree fixed=FALSE (curved) | see status line at the end of this file
* gwb1degree/gwb2degree attr= (fixed=TRUE) | IMPLEMENTED | bgwdegree1(decay, attr(var) levels()) | same
* b1nodematch, b2nodematch full | IMPLEMENTED | bnodematch1(var, diff alpha(#) beta(#) byattr(var) keep() levels()) | same; alpha/beta types as R's C code (beta type unless beta>=1 & alpha<1); byattr() is R's byb2attr/byb1attr; plain bnodematch1(var) unchanged
* nodemix on bipartite | IMPLEMENTED | nodemix(var) (b1 level x b2 level cells, first cell dropped as R) | same
* one-mode terms R accepts on bipartite: nodecov nodefactor nodematch(+diff) absdiff degree kstar concurrent degrange esp dsp gwesp gwdsp gwnsp triangle edgecov hamming | now accepted on bipartite | unchanged syntax | stat+design exact on A,B,C (dev/bip_spec2.txt)
* transitiveties, cyclicalties on bipartite: R accepts (value 0); nwergm still says "directed only" (not done: the undirected versions are not implemented for one-mode either)
* directed-only terms and gwdegree family on bipartite | R errors copied | "In term mutual: Term may not be used with networks with directed==FALSE." / "...bipartite > 0." (gwdegree*) ; bipartite terms on a one-mode network: "...bipartite==FALSE."
* simulate (bipartite) | IMPLEMENTED | nwergm simulate N, edges <bip options> bipartite(n1) theta(...) | smoke-tested (stat identical code path as estimation)
* gof (bipartite) | IMPLEMENTED | estat gof after a two-mode model: b1degree, b2degree, dspartners, distance tables (obs/min/mean/max/MC p) as R's default bipartite GOF | observed dsp row equals R's dsp(0:k) (167,34,20,8 on A); not compared draw by draw
* constraints on bipartite | blockdiag() works | nwergm bip, edges ... blockdiag(var) | MPLE equals R constraints=~blockdiag() (<1e-3 SE-level: -6.112807 vs -6.112807, SE 3.4547 vs 3.4546) on contiguous blocks. R REFUSES non-contiguous blocks ("requires that either the blocks be contiguous"), nwergm accepts any partition (not changed)
* edgecov(two-mode network) on bipartite | works | edgecov(netname) | MPLE equals R edgecov(matrix n1 x n2): -0.8346497/-0.046532/0.129772 vs -0.834650/-0.046532/0.129772
* spcache on bipartite | accepted, same numbers as without | spcache | MPLE dsp(1)+esp(0) equals R with cache.sp=FALSE
* NOTES / GOTCHAS
* - nwset, mat(M) bipartite takes the MODE-1 nodes from the matrix COLUMNS (not rows): to build a n1 x n2 network pass the n2 x n1 transpose. nwset person event, twomode cannot represent isolated nodes.
* - A stale ergm_mcmc_macos.plugin in the Stata PLUS folder shadows lib/plugins (findfile): copy the built plugin to the scratch tree root (dev runs do).
* - Mata: "*/" inside a /* */ comment (e.g. "b1*/b2*") ends the comment.
* - tempnames created in a helper ado can be recycled for later tempnames in the caller: Mata objects that must outlive the helper use their own counter names (__nwbx<N>).
* - logit tolerance for the MPLE tightened (tolerance(1e-9) ltolerance(1e-11), falls back to defaults on rc 430): default tolerance gave 1e-3 coefficient differences to R on weakly curved fits.
* - Native plugin: MAXTERMS 64 -> 256 (ErgmNativeSetup maxcols too); generic bipartite family = TERMCODE 3000+kind (1 DEGR 2 DEGRH 3 STARATTR 4 COVRANGE 5 FACTDIST 6 SOC 7 STARMIX 8 TWOSTAR 9 COINC 10 DSP 11 GWDSP 12 BNM 13 GWDEGA 14 MIX); curved MPLE (mode 2) now enumerates bipartite dyads only.
* - Not equal to R: models where R's MPLE is separated/degenerate (b1twostar with an empty cell gives -Inf in R; nwergm's MCMLE on that model does not terminate in reasonable time).
* - Term order in the coefficient table follows nwergm's option order, not the order of R's formula (the MCMLE comparison reorders).
* MCMLE (30x25 network, 50 ties; R 4 seeds, nwergm 3 seeds, difference of means in units of R's SE; nwergm seed-sd ~0.05 SE): conc 0.02, dsp 0.01, range 0.02, gwdsp 0.02, nodematch 0.01, nodematch alpha 0.04, starmix 0.09, covrange 0.14, factordistinct 0.01, degree by 0.06, star attr 0.03, sociality 0.04 (after re-ordering), gwdegree attr 0.02, nodemix+kstar 0.02. Not compared: b1twostar (R -Inf).
* term | status | nwergm syntax | validation (what, max difference)
* Validation set: 3 bipartite networks (A 12x10, B 8x15, C 20x6 with hubs and 2 isolated mode-1 nodes), dev/bip_gen.R; R ergm 4.12.0.
* (a) observed statistic == summary(), (b) change statistics == R ergmMPLE() design matrix over ALL dyads (sorted, 1e-6), (c) MPLE coefficients/SE vs ergm(estimate="MPLE")
* where R's fit is well identified, (d) MCMLE on a 30x25 network (50 ties), R 4 seeds vs nwergm 3 seeds. Files: dev/bip_spec*.txt, dev/bip_ref.R, dev/bip_run.do, cscripts/test_nwergm_bip.do (206 cases, passes).
* b1concurrent | IMPLEMENTED | bconcurrent1(all) / bconcurrent1(by(var) levels(numlist)) | stat+design exact on A,B,C; MPLE <1e-6; MCMLE 0.02 SE
* b2concurrent | IMPLEMENTED | bconcurrent2(all) / bconcurrent2(by(var)) | same
* b1mindegree, b2mindegree | IMPLEMENTED | bmindegree1(numlist), bmindegree2(numlist) | same (d=0 included, as R's emptynwstats)
* b1degrange, b2degrange | IMPLEMENTED | bdegrange1(from, to(numlist) by(var) levels() homophily), bdegrange2 | same; to=. is Inf
* b1degree, b2degree by= / levels= / homophily= | IMPLEMENTED | bdegree1(numlist, by(var) levels() homophily) | same; plain bdegree1(numlist) unchanged; ranges such as bdegree1(0/3) now expand (also degree, kstar, ... : numlist ranges)
* b1star, b2star attr=/levels= | IMPLEMENTED | bstar1(k, attr(var) levels()) | same; copies R quirk: values outside levels= are all recoded to one extra "other" value that matches itself (R 4.12.0 b1star(2,attr=,levels=1) counts stars among the other values)
* b1covrange, b2covrange | IMPLEMENTED | bcovrange1(var), bcovrange2(var) | same (x is a float in Stata: stat diff 2e-5)
* b1factordistinct, b2factordistinct | IMPLEMENTED | bfactordistinct1(var, levels()) | same
* b1sociality, b2sociality | IMPLEMENTED | bsociality1(numlist) e.g. bsociality1(-1) (R default nodes=-1), bsociality2 | same; numeric nodes= are POSITIONS within the mode (R: levels spec), not node ids
* b1starmix, b2starmix | IMPLEMENTED | bstarmix1(k, attr(var) nodiff base(numlist)) | same (diff=TRUE/FALSE, base=)
* b1twostar, b2twostar | IMPLEMENTED | btwostar1(var, attr2(var) levels1() levels2() levels3() base()) | same
* coincidence | IMPLEMENTED | coincidence(all), coincidence(active(#)) | same on B,C; on A the 45-parameter MPLE is quasi-separated (logit does not converge, R returns a fit)
* b1dsp, b2dsp | IMPLEMENTED | bdsp1(numlist), bdsp2 | same (d=0 counts all pairs of the mode)
* gwb1dsp, gwb2dsp fixed=TRUE | IMPLEMENTED | bgwdsp1(decay), bgwdsp2(decay) | same
* gwb1dsp, gwb2dsp, gwb1degree, gwb2degree fixed=FALSE (curved) | see status line at the end of this file
* gwb1degree/gwb2degree attr= (fixed=TRUE) | IMPLEMENTED | bgwdegree1(decay, attr(var) levels()) | same
* b1nodematch, b2nodematch full | IMPLEMENTED | bnodematch1(var, diff alpha(#) beta(#) byattr(var) keep() levels()) | same; alpha/beta types as R's C code (beta type unless beta>=1 & alpha<1); byattr() is R's byb2attr/byb1attr; plain bnodematch1(var) unchanged
* nodemix on bipartite | IMPLEMENTED | nodemix(var) (b1 level x b2 level cells, first cell dropped as R) | same
* one-mode terms R accepts on bipartite: nodecov nodefactor nodematch(+diff) absdiff degree kstar concurrent degrange esp dsp gwesp gwdsp gwnsp triangle edgecov hamming | now accepted on bipartite | unchanged syntax | stat+design exact on A,B,C (dev/bip_spec2.txt)
* transitiveties, cyclicalties on bipartite: R accepts (value 0); nwergm still says "directed only" (not done: the undirected versions are not implemented for one-mode either)
* directed-only terms and gwdegree family on bipartite | R errors copied | "In term mutual: Term may not be used with networks with directed==FALSE." / "...bipartite > 0." (gwdegree*) ; bipartite terms on a one-mode network: "...bipartite==FALSE."
* simulate (bipartite) | IMPLEMENTED | nwergm simulate N, edges <bip options> bipartite(n1) theta(...) | smoke-tested (stat identical code path as estimation)
* gof (bipartite) | IMPLEMENTED | estat gof after a two-mode model: b1degree, b2degree, dspartners, distance tables (obs/min/mean/max/MC p) as R's default bipartite GOF | observed dsp row equals R's dsp(0:k) (167,34,20,8 on A); not compared draw by draw
* constraints on bipartite | blockdiag() works | nwergm bip, edges ... blockdiag(var) | MPLE equals R constraints=~blockdiag() (<1e-3 SE-level: -6.112807 vs -6.112807, SE 3.4547 vs 3.4546) on contiguous blocks. R REFUSES non-contiguous blocks ("requires that either the blocks be contiguous"), nwergm accepts any partition (not changed)
* edgecov(two-mode network) on bipartite | works | edgecov(netname) | MPLE equals R edgecov(matrix n1 x n2): -0.8346497/-0.046532/0.129772 vs -0.834650/-0.046532/0.129772
* spcache on bipartite | accepted, same numbers as without | spcache | MPLE dsp(1)+esp(0) equals R with cache.sp=FALSE
* NOTES / GOTCHAS
* - nwset, mat(M) bipartite takes the MODE-1 nodes from the matrix COLUMNS (not rows): to build a n1 x n2 network pass the n2 x n1 transpose. nwset person event, twomode cannot represent isolated nodes.
* - A stale ergm_mcmc_macos.plugin in the Stata PLUS folder shadows lib/plugins (findfile): copy the built plugin to the scratch tree root (dev runs do).
* - Mata: "*/" inside a /* */ comment (e.g. "b1*/b2*") ends the comment.
* - tempnames created in a helper ado can be recycled for later tempnames in the caller: Mata objects that must outlive the helper use their own counter names (__nwbx<N>).
* - logit tolerance for the MPLE tightened (tolerance(1e-9) ltolerance(1e-11), falls back to defaults on rc 430): default tolerance gave 1e-3 coefficient differences to R on weakly curved fits.
* - Native plugin: MAXTERMS 64 -> 256 (ErgmNativeSetup maxcols too); generic bipartite family = TERMCODE 3000+kind (1 DEGR 2 DEGRH 3 STARATTR 4 COVRANGE 5 FACTDIST 6 SOC 7 STARMIX 8 TWOSTAR 9 COINC 10 DSP 11 GWDSP 12 BNM 13 GWDEGA 14 MIX); curved MPLE (mode 2) now enumerates bipartite dyads only.
* - Not equal to R: models where R's MPLE is separated/degenerate (b1twostar with an empty cell gives -Inf in R; nwergm's MCMLE on that model does not terminate in reasonable time).
* - Term order in the coefficient table follows nwergm's option order, not the order of R's formula (the MCMLE comparison reorders).
* MCMLE (30x25 network, 50 ties; R 4 seeds, nwergm 3 seeds, difference of means in units of R's SE; nwergm seed-sd ~0.05 SE): conc 0.02, dsp 0.01, range 0.02, gwdsp 0.02, nodematch 0.01, nodematch alpha 0.04, starmix 0.09, covrange 0.14, factordistinct 0.01, degree by 0.06, star attr 0.03, sociality 0.04 (after re-ordering), gwdegree attr 0.02, nodemix+kstar 0.02. Not compared: b1twostar (R -Inf).
* E6 (constraints, MH proposals, sampling controls)  -  branch ergmE6.  Format: term | status | nwergm syntax | validation
* =====================================================================================================================
* CONSTRAINTS (R ergm 4.12.0 `constraints=`; nwergm: constraints(<R-style formula>), several terms joined by + / -)
* edges            | done | constraints(edges)                          | exact enumeration (5-node undirected, 4-node directed); R simulate means (U,D); MCMLE vs R (4 seeds)
* degrees/nodedegrees | done | constraints(degrees)                     | exact enum undirected; R simulate (U); MCMLE vs R; directed: invariants + exact within R's own bias (see quirks)
* odegrees, idegrees | done | constraints(odegrees) / (idegrees)        | exact enum (directed); R simulate; MCMLE vs R
* b1degrees, b2degrees | done | constraints(b1degrees) / (b2degrees) / (b1degrees + b2degrees) | exact enumeration on a 3+3 two-mode network (CondB1Degree, CondB2Degree, CondDegree); bipartite blocks/blockdiag masks equal R (cross-mode dyads)
* degreedist       | done | constraints(degreedist)                     | exact enum undirected (pass); R simulate undirected and directed (pass)
* idegreedist      | done | constraints(idegreedist)                    | R simulate (directed, pass)
* odegreedist      | refused | -                                         | R 4.12.0 itself fails ("object 'proposals' not found" in InitErgmProposal.CondOutDegreeDist, directed); nwergm refuses with an explanation
* bd(attribs,maxout,maxin,minout,minin) | done | constraints(bd(maxout=3, ...)) | exact enum (undirected/directed); R simulate; MCMLE vs R. Max-only bounds error if the start violates them (R: BDStratTNT), with min bounds a warning (R: ergm_bd_init)
* blocks(attr,b1levels,b2levels,levels,levels2) | done | constraints(blocks(g, levels2=TRUE|FALSE|c(..)|-c(..))) | free-dyad masks identical to R for 4 specs x (undirected, directed); R simulate; MPLE vs R (1e-8)
* blockdiag(attr,noncontig) | done | constraints(blockdiag(g, noncontig=split)) | masks identical to R (incl. split, and refusal of noncontiguous blocks under merge); R simulate; MPLE vs R
* fixedas(fixed.dyads,present,absent) | done | constraints(fixedas(present=netP, absent=netA)) | exact enum; R simulate; MPLE vs R; the "present/absent do not match the network" errors as R
* fixallbut(free.dyads) | done | constraints(fixallbut(net))          | exact enum (also with edges); mask identical to R
* egocentric(attr,direction) | done | constraints(egocentric(e, direction=out)) | masks identical to R (both/out/in); attr omitted = nothing fixed
* observed         | done (needs missing dyads) | constraints(observed)    | free dyads = missing dyads; not validated against R (nwergm has no missing-data fitting path of its own)
* dyadnoise(p01,p10) | done | constraints(dyadnoise(0.1,0.2))           | exact enumeration with the noise likelihood in the target (both dyadnoiseTNT and dyadnoise proposals). Scalar p01/p10 only (R also allows matrices)
* hamming          | refused as R | -                                      | R 4.12.0: "Constraint 'hamming' is currently broken"; same message
* ChangeStats, Dyads, I | NOT done | -                                    | need formula-valued arguments (a model formula); no Stata equivalent chosen
* combinations     | done | e.g. fixallbut(net)+edges, blockdiag(g)+bd(maxout=5) | R's proposal-selection table reproduced (edges+dyads, bd+dyads allowed; degrees+dyads etc. refused with R's message)
* sign "-" (relaxing) | done | blocks(...) - blockdiag(g)                | masks identical to R ("((A|B)&C)|D" rule)
* PROPOSALS (native plugin, native/ergm_mcmc_e6.h, codes E6_*): TNT, randomtoggle, ConstantEdges (with dyad masks and bd), CondDegree (tetrad + hexad),
* CondOutDegree, CondInDegree, CondB1Degree, CondB2Degree, CondDegreeDist, CondInDegreeDist, CondOutDegreeDist (code present, refused at the formula level), dyadnoiseTNT, dyadnoise.
* BDStratTNT is realised as TNT + degree-bound rejection (same target distribution; R's version only differs in how proposals are stratified).
* NOT done: HammingTNT/HammingConstantEdges (only reachable through the broken hamming constraint), SPDyad (triadic hint), TNT10 (R marks it flawed), BipartiteCondDegreeDist (R's code writes the second toggle into the wrong slot), CondDegreeMix (degreesmix is not a user constraint), the strat hint's stratified TNT.
* mcmcprop(sparse|triadic|strat): validated like R's hint formula; unsupported hints fall back to TNT with R's "cannot take into account hint(s)" note.
* ESTIMATION / USE
* - MPLE under dyad-independent masks: coefficients and SEs equal R to 1e-7 (fixedas, blockdiag, blocks; U and D). Under dyad-dependent constraints (bd, edges, degrees, odegrees) MPLE is over all free dyads and the statistics held constant are 0 offsets, as R (R prints the "not implemented at this time" message; so does nwergm).
* - Statistics that a constraint holds constant (edges, degree(k), kstar, ostar, istar, sender, receiver ... per R's conflicts.constraints) are fixed at 0 and ignored, with R's wording.
* - Dyad-dependent constraint: default method is mcmle, start from zeros (R: MPLE not available), refit-from-estimate rounds (up to 5) because nwergm's convergence test can stop after one step from a far start.
* - MCMLE vs R (4 R seeds, tolerance max(4 sd_R, 0.06)): see test_nwergm_constr.do output.
* - obsconstraints(<formula>): second chain under constraints + obsconstraints, started from the network; estimating equation E_obs[g] = E[g], information Var - Var_obs (function ErgmMCMLEObs, a separate simpler Newton loop: ErgmMCMLE is untouched).
* - simulate: nwergm simulate N, ... basis(net) constraints(...): one chain from the basis network (R semantics), burn-in once, interval between draws. estat gof simulates under the fit's constraints (state kept in the fitted M/G objects).
* - controls: mcmcprop(), proposal(uniform|random|tnt), mcmcmaxedges() (R MCMC.maxedges; stops with an error), seed() (existing). R's defaults for burn-in/interval/sample size (16*interval / 1024 / adaptive) were NOT adopted: nwergm's MCMLE is a different algorithm and its defaults (3000/50/3000) are kept; owner decision. `parallel` not implemented (single process).
* R QUIRKS REPRODUCED / FOUND (ergm 4.12.0)
* - hamming constraint broken (stops); odegreedist on directed networks fails (typo `proposals$bd`); bipartite degreedist proposal mis-indexes its toggles.
* - CondDegree/CondDegreeDist rejection loops are unbounded in R: on a state with no valid tetrad (e.g. 4-node directed networks) R hangs forever; nwergm bounds them (1e6 tries) and treats the step as a null move.
* - The directed degrees/degreedist proposals are not exactly symmetric (rejection sampling conditional on the first edge): R and nwergm agree with each other (R simulate means within MC error) but not exactly with full enumeration (<=1% on the 4-node directed example).
* - CondDegreeDist keeps its node "tail" across retries and treats success on exactly the 100th/500th trial as failure; copied.
* - MPLE with dyad-dependent constraints: R only messages; edges held constant gives a coefficient of exactly 0 with warning.
* INTEGRATION NOTES FOR THE MERGER
* - New files: native/ergm_mcmc_e6.h (included from ergm_mcmc.c right before stata_call), _nwergm_constr.ado, _nwergm_hints.ado, nwergm_constraints.sthlp, cscripts/test_nwergm_constr.do, dev/e6_*.
* - Shared-file hunks: ergm_mcmc.c (E6 declarations/parse after `curved_decay_start`, column base `concol_base`, loop dispatch `if (e6c.code)`, frees), unw_ergm.do (ErgmModel.con_par/con_cols, SampleCore wire + guards in ErgmMCMCSample/Diag, appended E6 Mata block at the END: _ergm_con_*, ErgmSampleCon, ErgmMCMLEObs, _ergm_con_resetG, _ergm_con_conflicts),
* nwergm.ado (syntax: CONSTRAINTS OBSCONSTRAINTS MCMCMAXEDGES MCMCPROP; hunks tagged `constraints()`; nwergm_simulate: BASIS CONSTRAINTS), nwergm.sthlp (4 synopt lines), nwcommands-ado1.pkg/_pkg_ado.txt (+2 ado). Plugin wire: new trailing block `ncon_par par[] ncon_cols` after the curved fields; absent block = old behaviour; extra data columns sit between the mask block and the output columns.
* - lib/plugins/macos/ergm_mcmc_macos.plugin was rebuilt here: rebuild after merging (other agents also change ergm_mcmc.c).
* mple.type="penalized" (Firth) | done | mpletype(penalized) | flo/sampson/und(30)/dir(25)/separated(12): coef+SE vs R 4.13-dev ergm(estimate="MPLE"), max |diff| < 1e-6 (4.12.0 itself errors: 'length = 3' in coercion to 'logical(1)')
* MPLE.check (existence, Konis LP) | done | mplecheck(on|off) | separated 12-node network: warning "The MPLE does not exist!" and R's glm iterate reproduced exactly (-20.31201, 22.18381, SE 2602.54); for method(mcmle) only warns (start still from logit)
* MPLE.covariance.method | done | mplecovariance(invhess|godambe|bootstrap) | Godambe/bootstrap SE for dyad-dependent MPLE from 500 simulated networks (R: 0.58/0.84-0.90/0.0049 godambe, 0.62-0.64/5.3/0.0059 bootstrap) - see test notes
* init= | done | init(numlist, . = NA) | complete init skips the MPLE start; partial init held fixed in MPLE step; offset values from init override offset(); with estimate(mple) only offsets used (as R)
* offset / fixed coefficients vs R | checked | offset(coef value) | MPLE edges+triangle+offset(nodecov(wealth)) 0.01: coef/SE equal R to 1e-6; MCMLE within noise (edges -2.51 vs R -2.52)
* estimate="CD" | done | estimate(cd) / method(cd) | start zeros, CD.nsteps=8, samples 128*p, IS-Newton with Hummel steplength margin 0.5, Hotelling conv p>0.5; coefs inside the spread of 4 R seeds; SEs: R's vcov() is NA (MC part missing) - nwergm reports sqrt(diag(covar)) in e(V) because ereturn post cannot hold missing
* main.method="Stochastic-Approximation" | done | mainmethod(sa) | port of MCMCPhase12 (phase1 gain, 4 subphases) + phase-3 Newton step; edges/triangle/wealth and SEs within R's seed spread
* MCMLE.maxit | default now 60 (R) | mcmleiterations()
* MCMLE.confidence / termination / steplength / steplength.margin / effectiveSize | done | mcmleconfidence() mcmletermination(confidence|hummel|hotelling|none) mcmlesteplength() mcmlestepmargin() mcmleeffectivesize()
* MCMLE.metric (logtaylor, Median.Likelihood, EF.Likelihood), MCMLE.dampening, MCMLE.sequential, MCMLE.density.guard | NOT done | the Newton/lognormal step is the only metric
* also: obs.* (missing-data) controls are E1's
* "Unconstrained MCMC sampling did not mix at all" error | done (R wording) | nothing varies and the mean difference is nonzero
* simulate from a fit (simulate.ergm) | done | nwergm simulate, nsim() output(network|stats|edgelist) basis() nosequential seed() burnin() interval() coef() generate() clear | 4000-draw means/SDs of edges/triangle/wealth agree with R simulate() at the same coefficients (20.24 vs 20.19, 2205 vs 2198, 3.12 vs 3.10)
* not done: monitor=, constraints= (the fit's constraints are kept), response=, esteq=, parallel
* estat gof | done | estat gof, gof(degree idegree odegree b1degree b2degree espartners dspartners distance triadcensus model) nsim() ... | observed columns equal R gof() exactly for florentine (undirected) and sampson (directed): degree, idegree, odegree, esp, dsp, distance (incl. Inf), triad census (all 16 directed types; statnet 111D/111U convention), model; tables obs/min/mean/max/MC p-value as gof.ergm; plot option kept
* bipartite gof (b1degree, b2degree, dspartners) coded but not run against R
* estat mcmcdiag | done | appended to the existing output | mean/SD/naive+time-series SE/quantiles, observed-vs-sample z tests + Hotelling omnibus, cross/auto-correlation, Geweke z + individual + joint p; Mata port of ar.yw (Whittle) / spectrum0.mvar of ergm 4.12.0 matches R to 1e-8 on an autocorrelated sample
* parallel (cores) | NOT done (not cheap in Stata)
* ergm 4.13 NEWS: Firth MPLE fixed (applies; done), MPLE existence check solvers lpSolve/Rglpk (the LP is solved by an own simplex, not applicable), MCMLE metric sublist (naming only), gwesp/esp RTP fix (term agents), %d% dyadic covariates (no Stata analogue: edgecov() takes a network by name), rewritten convergence code (R-side internals; nwergm keeps its own confidence/Hotelling/Hummel logic), spectrum0.mvar changed to VAR-OLS (differs from 4.12.0, see GOTCHA)

* # UPDATE (branch operators, 2026-11-01).  Format: term | status | nwergm syntax | validation
* Sum, Prod, S, F, NodematchFilter, Symmetrize, Project (Proj1/Proj2), I, For, Label, Log, Exp, Offset | IMPLEMENTED | operators(Name(terms, suboptions)) | observed statistic (R summary), MPLE coefficients/SE (ergm(estimate="MPLE")) to 1e-4 (largest 8e-5, 94 comparisons on 7 networks), MCMLE within Monte Carlo noise for six models (two seeds) | test_nwergm_ops, test_nwergm_ops_native; dev/gen_test_ops.R
* Curve / Parametrise | PARTIAL | operators(Curve(terms, params() map(rep | matrix(name)))) | linear maps; MPLE equal to R to 1e-9 | test_nwergm_ops
* balance | IMPLEMENTED | structural(balance) | statistic exact, MPLE to 1e-5 (5 networks), MCMLE two seeds | test_nwergm_balance; dev/gen_test_balance.R
* gwb1degree, gwb2degree, gwb1dsp, gwb2dsp fixed=FALSE (curved) | IMPLEMENTED | bgwdegreefree1/2(start), bgwdspfree1/2(start) | MPLE coefficients/SE to 1e-6 on six two-mode networks; MCMLE (degree terms) within noise for two seeds | test_nwergm_bipcurved; dev/gen_test_bipcurved.R
* altkstar fixed=FALSE | PARTIAL | structural(altkstar) init(...) method(mple) | map/gradient equal R's; MPLE from given starting values equal to R to 2e-5 (4 networks x 4 starting values); R's default start fails and its MCMLE does not converge, so no MCMLE is offered | test_nwergm_altkstar; dev/gen_test_altkstar.R
* init= for curved terms | done for method(mple) | init(numlist, . = default) | gwesp/gwdegree free, 2 networks x 2 starting values, equal to R to 1e-9 | test_nwergm_altkstar
* R QUIRKS FOUND (ergm 4.12.0): Symmetrize(rule="weak") starts from a symmetrized network without the reciprocated pairs (MPLE/MCMLE differ from summary()); Prod statistics exact to 1e-8 only; altkstar(fixed=FALSE) cannot be fitted with default starting values.
