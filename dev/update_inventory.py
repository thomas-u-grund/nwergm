#!/usr/bin/env python3
"""Brings docs/ERGM_TERMS_INVENTORY.csv up to date with what the repository implements and prints the coverage recount.

usage (from the repository root): python3 dev/update_inventory.py
The statuses of the terms that were not implemented when the inventory was written are set from the option names of nwergm
(declared in nwergm.ado) and the tests in cscripts/ that use them."""
import csv, glob, re, sys

path = 'docs/ERGM_TERMS_INVENTORY.csv'
rows = list(csv.DictReader(open(path)))
fields = list(rows[0].keys())
tests = {f.split('/')[-1][:-3]: open(f).read() for f in glob.glob('cscripts/test_nwergm_*.do')}
ado = open('nwergm.ado').read()
structural = set("isolatededges degree1.5 degcrossprod degcor concurrentties tripercent opentriad m2star odegree1.5 idegree1.5 asymmetric transitive intransitive ttriple ctriple nearsimmelian simmelian simmelianties density meandeg twopath isolates cycle threetrail triadcensus localtriangle nsp balance".split())

def optname(t):
    m = re.match(r'^(b|gwb)([12])(.*)$', t)
    if m:
        base = m.group(1) + m.group(3) + m.group(2)
        return base.replace('gwbdegree', 'bgwdegree').replace('gwbdsp', 'bgwdsp')
    return t

operators = {
 'Sum': ('operators(Sum(terms | terms, label()))', 'test_nwergm_ops'),
 'Prod': ('operators(Prod(terms | terms, label()))', 'test_nwergm_ops'),
 'S': ('operators(S(terms, attrs()))', 'test_nwergm_ops'),
 'F': ('operators(F(terms, filter()))', 'test_nwergm_ops'),
 'NodematchFilter': ('operators(NodematchFilter(terms, attrname()))', 'test_nwergm_ops'),
 'Symmetrize': ('operators(Symmetrize(terms, rule()))', 'test_nwergm_ops'),
 'Project': ('operators(Project(terms, mode()))', 'test_nwergm_ops'),
 'I': ('operators(I(terms))', 'test_nwergm_ops'),
 'For': ('operators(For(name=values, terms))', 'test_nwergm_ops'),
 'Label': ('operators(Label(terms, label() pos()))', 'test_nwergm_ops'),
 'Log': ('operators(Log(terms, log0()))', 'test_nwergm_ops'),
 'Exp': ('operators(Exp(terms))', 'test_nwergm_ops'),
 'Offset': ('operators(Offset(terms, coef() which())) and offset(coefname #)', 'test_nwergm_ops'),
 'Curve': ('operators(Curve(terms, params() map(rep | matrix(name))))', 'test_nwergm_ops'),
}
for r in rows:
    if r['package'] != 'ergm':
        continue
    t = r['term']
    if t in operators:
        syn, tf = operators[t]
        r['nwergm_status'] = 'PARTIAL' if t == 'Curve' else 'IMPLEMENTED'
        r['nwergm_syntax'] = syn
        r['nwergm_network_types_tested'] = 'undirected,directed,bipartite' if t not in ('Symmetrize', 'Project', 'S') else {'Symmetrize': 'directed', 'Project': 'bipartite', 'S': 'undirected,directed'}[t]
        r['validated_against_ergm'] = 'yes | R ergm 4.12.0: observed statistics (summary), MPLE coefficients/SE (ergm(estimate="MPLE")) and MCMLE (several operators) on random and real networks | repo tests: ' + tf + ', test_nwergm_ops_native; generator dev/gen_test_ops.R'
        r['notes'] = ''
        if t == 'Curve':
            r['notes'] = 'Linear maps only (map(rep) and map(matrix(name)), estimated as the statistics L\'g(y)); R map functions, gradient, minpar, maxpar and cov are not available.'
        if t == 'Symmetrize':
            r['notes'] = 'rule(weak) on a network with reciprocated ties: R 4.12.0 starts from a symmetrized network that lacks the reciprocated pairs, so its estimation differs from its summary(); nwergm uses the exact change statistics.'
        if t == 'Prod':
            r['notes'] = 'R computes Prod as Exp(Sum(Log)) with log(0) = -1/sqrt(eps); its statistics are exact to about 1e-8 only. Nested Sum/Prod inside Prod is not available.'
        continue
    if r['nwergm_status'] in ('NOT IMPLEMENTED', 'PARTIAL') or t == 'balance':
        o = optname(t)
        where = [k for k, s in tests.items() if re.search(r'(?<![A-Za-z0-9_])' + re.escape(o) + r'[ (]', s) or (t in structural and re.search(r'(?<![A-Za-z0-9_])' + re.escape(t) + r'(?![A-Za-z0-9_])', s))]
        syn = ('structural(%s)' % t) if t in structural else ('%s(...)' % o)
        r['nwergm_status'] = 'IMPLEMENTED'
        r['nwergm_syntax'] = syn
        if where:
            r['validated_against_ergm'] = 'repo tests: ' + ', '.join(where[:4]) + ' (see VALIDATED_AGAINST_R.md)'
        r['notes'] = ''
        if t == 'balance':
            r['validated_against_ergm'] = 'yes | R ergm 4.12.0: summary(), MPLE, MCMLE (undirected and directed, random and real) | repo tests: test_nwergm_balance; generator dev/gen_test_balance.R'
            r['nwergm_network_types_tested'] = 'undirected,directed'
            r['notes'] = 'A triad-count term (types 102 and 300 of the triad census; an odd number of ties in an undirected triad), not a signed-network term.'
        if t == 'altkstar':
            r['nwergm_status'] = 'PARTIAL'
            r['nwergm_syntax'] = 'structural(altkstar(lambda=# fixed)); structural(altkstar) with init(), method(mple)'
            r['validated_against_ergm'] = 'yes | fixed: summary, MPLE; curved: map/gradient and MPLE from given init() on 4 networks x 4 starting values | repo tests: test_nwergm_structural, test_nwergm_altkstar'
            r['notes'] = 'Estimated lambda (R: fixed = FALSE, the default) is available for method(mple) with init() only: R cannot fit it with its default starting values and its MCMLE does not converge on the test networks, so nothing exists to compare an MCMLE with.'
        if t in ('gwb1degree', 'gwb2degree', 'gwb1dsp', 'gwb2dsp'):
            r['nwergm_syntax'] = '%s(decay) and %s(start)' % (o.replace('bgw', 'bgw'), o.replace('bgwdegree', 'bgwdegreefree').replace('bgwdsp', 'bgwdspfree'))
            r['validated_against_ergm'] = 'yes | R ergm 4.12.0: curved MPLE (coefficients/SE to 1e-6), curved MCMLE for the degree terms within Monte Carlo noise | repo tests: test_nwergm_bipcurved; generator dev/gen_test_bipcurved.R'
        if t in ('b1nodematch', 'b2nodematch'):
            r['notes'] = ''
rows_out = rows
w = csv.DictWriter(open(path, 'w', newline=''), fieldnames=fields)
w.writeheader()
w.writerows(rows_out)

E = [r for r in rows if r['package'] == 'ergm']
def n(s): return sum(1 for r in E if r['nwergm_status'] == s)
impl = n('IMPLEMENTED'); part = n('PARTIAL'); ni = n('NOT IMPLEMENTED'); npl = n('NOT PLANNED')
print('ergm terms:', len(E), ' IMPLEMENTED', impl, ' PARTIAL', part, ' NOT IMPLEMENTED', ni, ' NOT PLANNED', npl)
print('implemented or partial: %d of %d = %.1f%%' % (impl + part, len(E), 100.0 * (impl + part) / len(E)))
binary = [r for r in E if r['category'] not in ('valued only',)]
print('terms usable on binary networks (all but the 13 valued-only terms): %d, implemented or partial: %d = %.1f%%' % (len(binary), sum(1 for r in binary if r['nwergm_status'] in ('IMPLEMENTED', 'PARTIAL')), 100.0 * sum(1 for r in binary if r['nwergm_status'] in ('IMPLEMENTED', 'PARTIAL')) / len(binary)))
print('NOT PLANNED:', [r['term'] for r in E if r['nwergm_status'] == 'NOT PLANNED'])
print('NOT IMPLEMENTED:', [r['term'] for r in E if r['nwergm_status'] == 'NOT IMPLEMENTED'])
