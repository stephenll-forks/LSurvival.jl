# to implement
# - robust standard error estimate for Cox model
# - using formulas

using LSurvival, Random, Optim, BenchmarkTools

######################################################################
# residuals
######################################################################
"""
using LSurvival, Random
id, int, outt, dat = LSurvival.dgm(MersenneTwister(1212), 1000, 5);
d = dat[:,4]
x,z1,z2 = dat[:,1], dat[:,2], dat[:,3]
enter = zeros(length(t));

ft1 = coxph(@formula(Surv(int, outt, d)~x+z1+z2), (int=int,outt=outt,d=d,x=x,z1=z1,z2=z2), id=ID.(id), keepx=true, keepy=true)
ft1
resid = martingale(ft1)
sum(resid)
vid = values(ft1.R.id)
lididx = [findlast(vid .== id.value) for id in unique(ft1.R.id)]
sum(resid[lididx])

"""
function martingale(m::M) where {M<:PHModel}
    N = Float64.(m.R.y .> 0.0)
    resid = N .- expected(m)
    resid
end

function expected(m::M) where {M<:PHModel}
    B = coef(m)
    X = m.P.X
    rr = exp.(X * B)
    id = values(m.R.id)
    uid = unique(id)
    λ0 = m.bh[:,1]
    bht = m.bh[:,4]          
    dH = [λ0[findlast(bht .<= t)] for t in m.R.exit]
    incr = rr .* dH
    integrands = [cumsum(incr[findall(id .== ui)]) for ui in uid]
    reduce(vcat, integrands)
end

######################################################################
# fitting with optim
######################################################################

function fit!(
    m::PHModel;
    verbose::Bool = false,
    maxiter::Integer = 500,
    atol::Float64 = 0.0,
    rtol::Float64 = 0.0,
    gtol::Float64 = 1e-8,
    start = nothing,
    keepx = false,
    keepy = false,
    bootstrap_sample = false,
    bootstrap_rng = MersenneTwister(),
    kwargs...,
)
    m = bootstrap_sample ? bootstrap(bootstrap_rng, m) : m
    start = isnothing(start) ? zeros(length(m.P._B)) : start
    if haskey(kwargs, :ties)
        m.ties = kwargs[:ties]
    end
    ne = length(m.R.eventtimes)
    risksetidxs, caseidxs =
        Array{Array{Int,1},1}(undef, ne), Array{Array{Int,1},1}(undef, ne)
    _sumwtriskset, _sumwtcase = zeros(Float64, ne), zeros(Float64, ne)
    @inbounds @simd for j = 1:ne
        _outj = m.R.eventtimes[j]
        fr = findall((m.R.enter .< _outj) .&& (m.R.exit .>= _outj))
        fc = findall((m.R.y .> 0) .&& isapprox.(m.R.exit, _outj) .&& (m.R.enter .< _outj))
        risksetidxs[j] = fr
        caseidxs[j] = fc
        _sumwtriskset[j] = sum(m.R.wts[fr])
        _sumwtcase[j] = sum(m.R.wts[fc])
    end
    # cox risk and set to zero were both in step cox - return them?
    # loop over event times
    #LSurvival._coxrisk!(m.P) # updates all elements of _r as exp(X*_B)
    #LSurvival._settozero!(m.P)
    #LSurvival._partial_LL!(m, risksetidxs, caseidxs, ne, den)

    function coxupdate!(
        F,
        G,
        H,
        beta,
        m;
        ne = ne,
        caseidxs = caseidxs,
        risksetidxs = risksetidxs,
    )
        m.P._LL[1] = isnothing(F) ? m.P._LL[1] : F
        m.P._grad = isnothing(G) ? m.P._grad : G
        m.P._hess = isnothing(H) ? m.P._hess : H
        m.P._B = isnothing(beta) ? m.P._B : beta
        #
        LSurvival._update_PHParms!(m, ne, caseidxs, risksetidxs)
        # turn into a minimization problem
        F = -m.P._LL[1]
        m.P._grad .*= -1.0
        m.P._hess .*= -1.0
        F
    end

    fgh! = TwiceDifferentiable(
        Optim.only_fgh!((F, G, H, beta) -> coxupdate!(F, G, H, beta, m)),
        start,
    )
    opt = NewtonTrustRegion()
    #opt = IPNewton()
    #opt = Newton()
    res = optimize(
        fgh!,
        start,
        opt,
        Optim.Options(
            f_abstol = atol,
            f_reltol = rtol,
            g_tol = gtol,
            iterations = maxiter,
            store_trace = true,
        ),
    )
    verbose && println(res)

    m.fit = true
    m.P._grad .*= -1.0
    m.P._hess .*= -1.0
    m.P._LL = [-x.value for x in res.trace]
    basehaz!(m)
    m.P.X = keepx ? m.P.X : nothing
    m.R = keepy ? m.R : nothing
    m
end



id, int, outt, data = LSurvival.dgm(MersenneTwister(345), 100, 10; afun = LSurvival.int_0);
data[:, 1] = round.(data[:, 1], digits = 3);
d, X = data[:, 4], data[:, 1:3];


# not-yet-fit PH model object
#m = PHModel(R, P, "breslow")
#LSurvival._fit!(m, start = [0.0, 0.0, 0.0], keepx=true, keepy=true)
#isfitted(m)
R = LSurvResp(int, outt, d)
P = PHParms(X)
m = PHModel(R, P);  #default is "efron" method for ties
@btime res = LSurvival._fit!(m, start = [0.0, 0.0, 0.0], keepx = true, keepy = true);

R2 = LSurvResp(int, outt, d);
P2 = PHParms(X);
m2 = PHModel(R2, P2);  #default is "efron" method for ties
@btime res2 = fit!(m2, start = [0.0, 0.0, 0.0], keepx = true, keepy = true);

res
res2

argmax([res.P._LL[end], res2.P._LL[end]])

res.P._LL[end] - res2.P._LL[end]

# in progress functions
# taken from GLM.jl/src/linpred.jl
