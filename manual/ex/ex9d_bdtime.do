do setup.doh
nwwebuse lazega, nwclear
encode practice, generate(prac)
timer clear 1
timer on 1
quietly nwergm lazega_fr, edges mutual nodematch(prac) constraints(bd(maxout=30)) seed(1)
timer off 1
quietly timer list 1
display "RESULT bd(maxout=30): " r(t1) " seconds, iterations " e(mcmle_iterations) " converged " e(converged)
timer clear 2
timer on 2
quietly nwergm lazega_fr, edges mutual nodematch(prac) seed(1)
timer off 2
quietly timer list 2
display "RESULT unconstrained: " r(t2) " seconds, iterations " e(mcmle_iterations)
