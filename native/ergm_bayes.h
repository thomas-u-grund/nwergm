/* ergm_bayes.h -- the exchange algorithm for Bayesian ERGM estimation (Caimo and Friel 2011) in its adaptive
   direction sampling form with the adaptive-scaling and delayed-acceptance extensions of R's Bergm 6.0.0
   (bergm()). This file holds only the sampler of the parameter population (proposals, prior, acceptance,
   adaptation, delayed-acceptance surrogate, storage of the draws); the auxiliary network at a proposed
   parameter is drawn by the Metropolis-Hastings loop of ergm_mcmc.c (stata_call, mode 7), which asks this
   state machine for the next proposal (bayes_next) and hands the statistics of the auxiliary network back
   (bayes_done). Included by ergm_mcmc.c after the graph code. */

#define BAYES_MAXT 256

typedef struct {
	long nch, nt, ne, pf, ncurved;
	long burn, main_it, thin, nkeep, tot, k, h;
	int adapt, da, use_da, in_burn;
	double target, log_gamma, dainflate, vsd;
	int *freeb, *decb;
	double *theta;      /* nch x nt working parameters (decay on the log scale), row-major by chain */
	double *fixval;     /* nt, the value of a fixed (offset) parameter, natural scale */
	double *pmean;      /* nt, prior mean (working scale) */
	double *P;          /* nt x nt prior precision, nonzero on the estimated non-decay parameters only */
	double dmeanlog, dsdlog;
	double *lp, *eta, *sur_cur, *E;
	long *acc;
	double *prop, *prop_eta, prop_lp, prop_s1;
	long cur_h;
	long n_prop, n_sim, n_sim_burn, n_da_reject, n_fail;
	double *da_store, *da_m, *da_L;
	long da_start, da_row, da_cap;
	double *sy;         /* ne observed statistics */
	double *out;        /* nch * nkeep * nt, chain-major */
	long acc_iter;
	int state;          /* 0 start of an iteration, 1 inside the chain loop */
} bayes_t;

static double bayes_norm(rng_t *r) {
	double u1, u2;
	do { u1 = rng_unif(r); } while (u1 <= 0.0);
	u2 = rng_unif(r);
	return sqrt(-2.0 * log(u1)) * cos(6.283185307179586477 * u2);
}

/* natural-scale parameters (decay exponentiated, fixed values filled in) and the canonical parameters eta */
static void bayes_eta(const bayes_t *B, const double *w, double *eta) {
	double nat[BAYES_MAXT];
	long j, nord;
	for (j = 0; j < B->nt; j++) {
		if (!B->freeb[j]) nat[j] = B->fixval[j];
		else nat[j] = B->decb[j] ? exp(w[j]) : w[j];
	}
	nord = B->ne - B->ncurved;
	for (j = 0; j < nord; j++) eta[j] = nat[j];
	if (B->ncurved > 0) gwdecay_map(nat[B->nt - 2], nat[B->nt - 1], B->ncurved, eta + nord);
}

static double bayes_logprior(const bayes_t *B, const double *w) {
	double q = 0.0, d[BAYES_MAXT];
	long i, j;
	for (j = 0; j < B->nt; j++) d[j] = w[j] - B->pmean[j];
	for (i = 0; i < B->nt; i++) {
		double s = 0.0;
		if (B->P[i * B->nt + i] == 0.0 && !B->decb[i]) continue;
		for (j = 0; j < B->nt; j++) s += B->P[i * B->nt + j] * d[j];
		q += d[i] * s;
	}
	q = -0.5 * q;
	for (j = 0; j < B->nt; j++) if (B->decb[j]) {
		double z = (w[j] - B->dmeanlog) / B->dsdlog;
		q -= 0.5 * z * z;
	}
	return q;
}

/* Cholesky factor (lower) of the m x m symmetric matrix S into L; returns 0 when S is not positive definite */
static int bayes_chol(const double *S, long m, double *L) {
	long i, j, k;
	for (i = 0; i < m; i++) {
		for (j = 0; j <= i; j++) {
			double s = S[i * m + j];
			for (k = 0; k < j; k++) s -= L[i * m + k] * L[j * m + k];
			if (i == j) {
				if (!(s > 1e-300)) return 0;
				L[i * m + i] = sqrt(s);
			}
			else L[i * m + j] = s / L[j * m + j];
		}
		for (j = i + 1; j < m; j++) L[i * m + j] = 0.0;
	}
	return 1;
}

static double bayes_sur(const bayes_t *B, const double *w) {
	double r[BAYES_MAXT], q = 0.0;
	long i, j, c = 0, idx[BAYES_MAXT];
	for (j = 0; j < B->nt; j++) if (B->freeb[j]) idx[c++] = j;
	for (i = 0; i < B->pf; i++) {
		double s = w[idx[i]] - B->da_m[i];
		for (j = 0; j < i; j++) s -= B->da_L[i * B->pf + j] * r[j];
		r[i] = s / B->da_L[i * B->pf + i];
		q += r[i] * r[i];
	}
	return -0.5 * q;
}

static int bayes_init(bayes_t *B, long ne, const double *sy) {
	long nch, nt, j, c, i;
	ST_double v;
	char nm[64];
	memset(B, 0, sizeof(*B));
	B->ne = ne;
	SF_scal_use("__eb_ncurved", &v); B->ncurved = (long)v;
	if (SF_scal_use("__eb_nch", &v)) return 1; nch = (long)v; B->nch = nch;
	SF_scal_use("__eb_nt", &v); nt = (long)v; B->nt = nt;
	SF_scal_use("__eb_burn", &v); B->burn = (long)v;
	SF_scal_use("__eb_main", &v); B->main_it = (long)v;
	SF_scal_use("__eb_thin", &v); B->thin = (long)v; if (B->thin < 1) B->thin = 1;
	SF_scal_use("__eb_adapt", &v); B->adapt = (int)v;
	SF_scal_use("__eb_target", &v); B->target = (double)v;
	SF_scal_use("__eb_gamma", &v); B->log_gamma = log((double)v);
	SF_scal_use("__eb_da", &v); B->da = (int)v;
	SF_scal_use("__eb_dainflate", &v); B->dainflate = (double)v;
	SF_scal_use("__eb_vprop", &v); B->vsd = sqrt((double)v);
	SF_scal_use("__eb_dmeanlog", &v); B->dmeanlog = (double)v;
	SF_scal_use("__eb_dsdlog", &v); B->dsdlog = (double)v;
	if (nt < 1 || nt > BAYES_MAXT || ne > BAYES_MAXT || nch < 3) return 2;
	B->nkeep = B->main_it / B->thin;
	B->tot = B->burn + B->main_it;
	B->freeb = (int *)calloc((size_t)nt, sizeof(int)); B->decb = (int *)calloc((size_t)nt, sizeof(int));
	B->theta = (double *)calloc((size_t)(nch * nt), sizeof(double));
	B->fixval = (double *)calloc((size_t)nt, sizeof(double)); B->pmean = (double *)calloc((size_t)nt, sizeof(double));
	B->P = (double *)calloc((size_t)(nt * nt), sizeof(double));
	B->lp = (double *)calloc((size_t)nch, sizeof(double)); B->eta = (double *)calloc((size_t)(nch * ne), sizeof(double));
	B->sur_cur = (double *)calloc((size_t)nch, sizeof(double));
	B->acc = (long *)calloc((size_t)nch, sizeof(long));
	B->prop = (double *)calloc((size_t)nt, sizeof(double)); B->prop_eta = (double *)calloc((size_t)ne, sizeof(double));
	B->sy = (double *)calloc((size_t)ne, sizeof(double));
	B->out = (double *)calloc((size_t)(nch * (B->nkeep > 0 ? B->nkeep : 1) * nt), sizeof(double));
	if (!B->freeb || !B->decb || !B->theta || !B->fixval || !B->pmean || !B->P || !B->lp || !B->eta || !B->sur_cur || !B->acc || !B->prop || !B->prop_eta || !B->sy || !B->out) return 3;
	for (j = 0; j < ne; j++) B->sy[j] = sy[j];
	for (j = 0; j < nt; j++) {
		ST_double f = 0, d = 0, fv = 0, pm = 0;
		if (SF_mat_el("__eb_par", 1, (int)(j + 1), &f)) return 4;
		SF_mat_el("__eb_par", 2, (int)(j + 1), &d);
		SF_mat_el("__eb_par", 3, (int)(j + 1), &fv);
		SF_mat_el("__eb_par", 4, (int)(j + 1), &pm);
		B->freeb[j] = (f != 0); B->decb[j] = (d != 0); B->fixval[j] = (double)fv; B->pmean[j] = (double)pm;
		if (B->freeb[j]) B->pf++;
		for (i = 0; i < nt; i++) {
			ST_double pv = 0;
			SF_mat_el("__eb_prec", (int)(j + 1), (int)(i + 1), &pv);
			B->P[j * nt + i] = (double)pv;
		}
	}
	for (c = 0; c < nch; c++) for (j = 0; j < nt; j++) {
		ST_double tv = 0;
		if (SF_mat_el("__eb_theta0", (int)(c + 1), (int)(j + 1), &tv)) return 5;
		B->theta[c * nt + j] = (double)tv;
	}
	B->E = (double *)calloc((size_t)(nch * (B->pf > 0 ? B->pf : 1)), sizeof(double));
	if (!B->E) return 3;
	snprintf(nm, sizeof(nm), "__eb_par");
	if (B->da && B->burn >= 10 && B->pf > 0) {
		B->da_start = B->burn / 2 + 1;
		B->da_cap = (B->burn - B->da_start + 1) * nch;
		B->da_store = (double *)calloc((size_t)(B->da_cap * B->pf), sizeof(double));
		B->da_m = (double *)calloc((size_t)B->pf, sizeof(double));
		B->da_L = (double *)calloc((size_t)(B->pf * B->pf), sizeof(double));
		if (!B->da_store || !B->da_m || !B->da_L) return 3;
	}
	else B->da = 0;
	for (c = 0; c < nch; c++) {
		bayes_eta(B, B->theta + c * nt, B->eta + c * ne);
		B->lp[c] = bayes_logprior(B, B->theta + c * nt);
		if (!(B->lp[c] > -1e300)) return 6;
	}
	B->k = 1; B->h = 0; B->state = 0;
	return 0;
}

static void bayes_free(bayes_t *B) {
	free(B->freeb); free(B->decb); free(B->theta); free(B->fixval); free(B->pmean); free(B->P);
	free(B->lp); free(B->eta); free(B->sur_cur); free(B->E); free(B->acc); free(B->prop); free(B->prop_eta);
	free(B->da_store); free(B->da_m); free(B->da_L); free(B->sy); free(B->out);
}

/* end of one iteration k: adaptation, fit of the surrogate, storage of the draws */
static void bayes_endit(bayes_t *B) {
	long c, j, i, f;
	if (B->in_burn) {
		if (B->adapt) {
			B->log_gamma += ((double)B->acc_iter / (double)B->nch - B->target) / pow((double)B->k + 1.0, 0.6);
			if (B->log_gamma < log(0.001)) B->log_gamma = log(0.001);
			if (B->log_gamma > log(10.0)) B->log_gamma = log(10.0);
		}
		if (B->da && B->k >= B->da_start) {
			for (c = 0; c < B->nch; c++) {
				f = 0;
				for (j = 0; j < B->nt; j++) if (B->freeb[j]) B->da_store[(B->da_row + c) * B->pf + f++] = B->theta[c * B->nt + j];
			}
			B->da_row += B->nch;
		}
		if (B->da && B->k == B->burn) {
			long m = B->da_row, pf = B->pf;
			double *S = (double *)calloc((size_t)(pf * pf), sizeof(double));
			if (S && m > pf) {
				for (j = 0; j < pf; j++) { double s = 0; for (i = 0; i < m; i++) s += B->da_store[i * pf + j]; B->da_m[j] = s / (double)m; }
				for (j = 0; j < pf; j++) for (c = 0; c <= j; c++) {
					double s = 0;
					for (i = 0; i < m; i++) s += (B->da_store[i * pf + j] - B->da_m[j]) * (B->da_store[i * pf + c] - B->da_m[c]);
					s = s / (double)(m - 1) * B->dainflate;
					S[j * pf + c] = S[c * pf + j] = s;
				}
				if (bayes_chol(S, pf, B->da_L)) {
					B->use_da = 1;
					for (c = 0; c < B->nch; c++) B->sur_cur[c] = bayes_sur(B, B->theta + c * B->nt);
				}
			}
			free(S);
			free(B->da_store); B->da_store = NULL;
		}
	}
	else {
		long kk = B->k - B->burn;
		if (kk % B->thin == 0) {
			long idx = kk / B->thin - 1;
			for (c = 0; c < B->nch; c++) for (j = 0; j < B->nt; j++) {
				double w = B->theta[c * B->nt + j];
				B->out[((c * B->nkeep) + idx) * B->nt + j] = B->decb[j] ? exp(w) : (B->freeb[j] ? w : B->fixval[j]);
			}
		}
	}
}

/* next proposal that needs an auxiliary network: returns 1 and fills prop_eta (cur_h = the chain), or 0 when the run is over */
static int bayes_next(bayes_t *B, rng_t *rng) {
	for (;;) {
		long h, a, b, j, f;
		double g, lpp, s1;
		if (B->state == 0) {
			if (B->k > B->tot) return 0;
			B->in_burn = (B->k <= B->burn);
			for (j = 0; j < B->nch * B->pf; j++) B->E[j] = B->vsd * bayes_norm(rng);
			B->acc_iter = 0; B->h = 0; B->state = 1;
		}
		if (B->h >= B->nch) {
			bayes_endit(B);
			B->k++; B->state = 0;
			continue;
		}
		h = B->h++;
		g = exp(B->log_gamma);
		a = rng_below(rng, B->nch - 1); b = rng_below(rng, B->nch - 2);
		if (b >= a) b++;
		if (a >= h) a++;
		if (b >= h) b++;
		for (j = 0; j < B->nt; j++) B->prop[j] = B->theta[h * B->nt + j];
		f = 0;
		for (j = 0; j < B->nt; j++) if (B->freeb[j]) {
			B->prop[j] += g * (B->theta[a * B->nt + j] - B->theta[b * B->nt + j]) + B->E[h * B->pf + f];
			f++;
		}
		lpp = bayes_logprior(B, B->prop);
		B->n_prop++;
		if (!(lpp > -1e300)) continue;
		s1 = 0.0;
		if (B->use_da) {
			s1 = bayes_sur(B, B->prop) - B->sur_cur[h];
			if (!(log(rng_unif(rng)) < s1)) { B->n_da_reject++; continue; }
		}
		bayes_eta(B, B->prop, B->prop_eta);
		for (j = 0; j < B->ne; j++) if (!(B->prop_eta[j] == B->prop_eta[j])) break;
		if (j < B->ne) continue;
		B->prop_lp = lpp; B->prop_s1 = s1; B->cur_h = h;
		if (B->in_burn) B->n_sim_burn++; else B->n_sim++;
		return 1;
	}
}

/* the statistics s of the auxiliary network at the proposal: acceptance of the exchange move */
static void bayes_done(bayes_t *B, rng_t *rng, const double *s) {
	long h = B->cur_h, j;
	double logr = 0.0;
	for (j = 0; j < B->ne; j++) {
		double d = B->prop_eta[j] - B->eta[h * B->ne + j];
		if (d != 0.0 && d == d) logr += d * (B->sy[j] - s[j]);
	}
	logr += B->prop_lp - B->lp[h] - B->prop_s1;
	if (log(rng_unif(rng)) < logr) {
		for (j = 0; j < B->nt; j++) B->theta[h * B->nt + j] = B->prop[j];
		for (j = 0; j < B->ne; j++) B->eta[h * B->ne + j] = B->prop_eta[j];
		B->lp[h] = B->prop_lp;
		if (B->use_da) B->sur_cur[h] = bayes_sur(B, B->prop);
		B->acc_iter++;
		if (!B->in_burn) B->acc[h]++;
	}
}
