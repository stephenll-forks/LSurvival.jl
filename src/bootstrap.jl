
"""
```
id, int, outt, data =
LSurvival.dgm(MersenneTwister(1212), 20, 5; afun = LSurvival.int_0)

d, X = data[:, 4], data[:, 1:3]
weights = rand(length(d))

# survival outcome:
R = LSurvResp(int, outt, d, ID.(id))    # specification with ID only
```
"""
function bootstrap(rng::MersenneTwister, R::T) where {T<:LSurvResp}
    uid = unique(R.id)
    bootid = sort(rand(rng, uid, length(uid)))
    idxl = [findall(getfield.(R.id, :value) .== bootidi.value) for bootidi in bootid]
    idx = reduce(vcat, idxl)
    nid = ID.(reduce(vcat, [fill(i, length(idxl[i])) for i in eachindex(idxl)]))
    R.id[idx]
    R2 = LSurvResp(R.enter[idx], R.exit[idx], R.y[idx], R.wts[idx], nid)
    idx, R2
end
bootstrap(R::T) where {T<:LSurvResp} = bootstrap(MersenneTwister(), R::T)


"""
```
z,x,t,d,event,weights =
LSurvival.dgm_comprisk(MersenneTwister(1212), 300)
enter = zeros(length(event))

# survival outcome:
R = LSurvCompResp(enter, t, event, weights, ID.(collect(1:length(t))))    # specification with ID only
bootstrap(R) # note that entire observations/clusters identified by id are kept
```
"""
function bootstrap(rng::MersenneTwister, R::T) where {T<:LSurvCompResp}
    uid = unique(R.id)
    bootid = sort(rand(rng, uid, length(uid)))
    idxl = [findall(getfield.(R.id, :value) .== bootidi.value) for bootidi in bootid]
    idx = reduce(vcat, idxl)
    nid = ID.(reduce(vcat, [fill(i, length(idxl[i])) for i in eachindex(idxl)]))
    R.id[idx]
    R2 = LSurvCompResp(R.enter[idx], R.exit[idx], R.y[idx], R.wts[idx], nid)
    idx, R2
end
bootstrap( R::T) where {T<:LSurvCompResp} = bootstrap(MersenneTwister(), R::T)

"""
```
using LSurvival, Random

id, int, outt, data =
LSurvival.dgm(MersenneTwister(1212), 20, 5; afun = LSurvival.int_0)

d, X = data[:, 4], data[:, 1:3]
weights = rand(length(d))

# survival outcome:
R = LSurvResp(int, outt, d, ID.(id))    # specification with ID only
P = PHParms(X)
idx, R2 = bootstrap(R)
P2 = bootstrap(idx, P)

Mod = PHModel(R2, P2)
LSurvival._fit!(Mod, start=Mod.P._B)

```

"""
function bootstrap(idx::Vector{Int}, P::PHParms)
    P2 = PHParms(P.X[idx, :])
    P2
end

"""
```
bootstrap(rng::MersenneTwister, m::PHModel)
```

```julia-repl
using LSurvival, Random

id, int, outt, data =
LSurvival.dgm(MersenneTwister(1212), 500, 5; afun = LSurvival.int_0)

d, X = data[:, 4], data[:, 1:3]
weights = rand(length(d))

# survival outcome:
R = LSurvResp(int, outt, d, ID.(id))    # specification with ID only
P = PHParms(X)

Mod = PHModel(R, P)
LSurvival._fit!(Mod, start=Mod.P._B)


# careful propogation of bootstrap sampling
idx, R2 = bootstrap(R)
P2 = bootstrap(idx, P)
Modb = PHModel(R2, P2)
LSurvival._fit!(Mod, start=Mod.P._B)

# convenience function for bootstrapping a model
Modc = bootstrap(Mod)
LSurvival._fit!(Modc, start=Modc.P._B)
Modc.P.X = nothing
Modc.R = nothing

```
"""
function bootstrap(rng::MersenneTwister, m::PHModel)
    idx, R2 = bootstrap(rng, m.R)
    P2 = bootstrap(idx, m.P)
    PHModel(R2, P2, m.ties, false, m.bh)
end
bootstrap(m::PHModel) = bootstrap(MersenneTwister(), m)


"""
    bootstrap(rng::MersenneTwister, m::PHModel, iter::Int; kwargs...)

Bootstrap Cox model coefficients
```
LSurvival._fit!(mb, keepx=true, keepy=true, start=[0.0, 0.0])
```

```julia-repl
using LSurvival, Random
res = z, x, outt, d, event, wts = LSurvival.dgm_comprisk(MersenneTwister(123123), 100)
int = zeros(length(d)) # no late entry
X = hcat(z, x)

mainfit = fit(PHModel, X, int, outt, d .* (event .== 1), keepx=true, keepy=true)

mb = bootstrap(mainfit, 1000)
mainfit

```
"""
function bootstrap(rng::MersenneTwister, m::PHModel, iter::Int; kwargs...)
    if isnothing(m.R) || isnothing(m.P.X)
        throw("Model is missing response or predictor matrix, use keepx=true, keepy=true")
    end
    res = zeros(iter, length(coef(m)))
    @inbounds for i = 1:iter
        mb = bootstrap(rng, m)
        LSurvival._fit!(mb; kwargs...)
        res[i, :] = mb.P._B
    end
    res
end
bootstrap(m::PHModel, iter::Int; kwargs...) =
    bootstrap(MersenneTwister(), m, iter; kwargs...)



"""
using LSurvival
using Random

id, int, outt, data =
LSurvival.dgm(MersenneTwister(1212), 20, 5; afun = LSurvival.int_0)

d, X = data[:, 4], data[:, 1:3]
wts = rand(length(d))

km1 = kaplan_meier(int, outt, d, id=ID.(id), wts=wts)
km2 = bootstrap(km1, keepy=false)
km1

km1.R
km2.R

"""
function bootstrap(rng::MersenneTwister, m::M;kwargs...) where{M<:KMSurv}
    _, R2 = bootstrap(rng, m.R)
    boot = KMSurv(R2)
    LSurvival._fit!(boot;kwargs...)
end
bootstrap(m::M;kwargs...) where{M<:KMSurv} = bootstrap(MersenneTwister(), m;kwargs...)




"""
using LSurvival
using Random

z, x, t, d, event, wt = LSurvival.dgm_comprisk(MersenneTwister(1212), 100)
enter = zeros(length(t))

aj1 = aalen_johansen(enter, t, event, id=ID.(id), wts=wt)
aj2 = bootstrap(aj1, keepy=false);
aj1


aj1.R
aj2.R

"""
function bootstrap(rng::MersenneTwister, m::M;kwargs...) where{M<:AJSurv}
    _, R2 = bootstrap(rng, m.R)
    boot = AJSurv(R2)
    LSurvival._fit!(boot;kwargs...)
end
bootstrap(m::M; kwargs...) where{M<:AJSurv} = bootstrap(MersenneTwister(), m;kwargs...)
